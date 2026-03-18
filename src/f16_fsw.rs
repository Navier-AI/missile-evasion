use nalgebra::Vector3;
use stellarust_core::state::RigidBodyState;
use stellarust_sim::dynamics::ForcesTorques;
use stellarust_sim::harness::{ActuatorCommands, FlightSoftware, SensorInput};
use stellarust_sim::ForceModel;
use stellarust_core::system::{ThrustCommand, TorqueCommand};
use stellarust_core::{Quaternion, System};
use stellarust_gnc::{PidController, PidInput};

use crate::vehicles::*;

// ============================================================
// Aerodynamic Force Model for F-16
// ============================================================

pub struct F16AeroForce {
    wing_area: f64,
    cl_alpha: f64,
    cd0: f64,
    cl_max: f64,
    mass: f64,
    g_limit: f64,
}

impl F16AeroForce {
    pub fn new() -> Self {
        Self {
            wing_area: 27.87,   // F-16 wing area [m²]
            cl_alpha: 3.44,     // lift curve slope [1/rad]
            cd0: 0.025,         // parasitic drag coefficient
            cl_max: 1.2,        // max CL (limited for structural G)
            mass: F16_MASS_KG,
            g_limit: 9.0,       // structural limit
        }
    }
}

impl ForceModel for F16AeroForce {
    fn forces(&self, state: &RigidBodyState, _commands: &ActuatorCommands) -> ForcesTorques {
        let v_ned = state.velocity;
        let speed = v_ned.norm();
        if speed < 1.0 {
            return ForcesTorques::zero();
        }

        // Atmospheric density at altitude (exponential model)
        let altitude = (-state.position.z).max(0.0);
        let rho = 1.225 * (-altitude / 8500.0).exp();

        // Dynamic pressure
        let q = 0.5 * rho * speed * speed;

        // Velocity in body frame
        let v_body = state.attitude.conjugate().rotate(&v_ned);

        // Angle of attack
        let alpha = libm::atan2(v_body.z, v_body.x);

        // Lift coefficient (linear until stall, clamped)
        let cl = (self.cl_alpha * alpha).clamp(-self.cl_max, self.cl_max);

        // Drag coefficient (parabolic polar)
        let aspect_ratio = 3.2;
        let oswald = 0.8;
        let cd = self.cd0 + cl * cl / (std::f64::consts::PI * oswald * aspect_ratio);

        // Aero forces in body frame
        let lift_force = q * self.wing_area * cl;
        let drag_force = q * self.wing_area * cd;

        // Structural G-limit: clamp total normal force
        let g0 = 9.80665;
        let max_normal_force = self.g_limit * self.mass * g0;
        let lift_clamped = lift_force.clamp(-max_normal_force, max_normal_force);

        let force_body = Vector3::new(-drag_force, 0.0, -lift_clamped);

        // Rotate to NED frame
        let force_ned = state.attitude.rotate(&force_body);

        ForcesTorques {
            force: force_ned,
            torque: Vector3::zeros(),
        }
    }

    fn name(&self) -> &str {
        "F16AeroForce"
    }
}

// ============================================================
// F-16 Flight Software
// ============================================================

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum F16Phase {
    Cruise,
    BreakTurn,
    Extend,
}

pub struct F16Fsw {
    phase: F16Phase,
    time: f64,
    break_start_time: f64,

    pitch_pid: PidController,
    roll_pid: PidController,

    pos: Vector3<f64>,
    vel: Vector3<f64>,
    att: Quaternion,

    g_load: f64,
    altitude: f64,
    speed: f64,
    range_to_missile: f64,
    bank_angle_deg: f64,
}

fn quaternion_to_euler(q: &Quaternion) -> (f64, f64, f64) {
    let dcm = q.to_dcm();
    let pitch = libm::asin((-dcm[(2, 0)]).clamp(-1.0, 1.0));
    let roll = libm::atan2(dcm[(2, 1)], dcm[(2, 2)]);
    let yaw = libm::atan2(dcm[(1, 0)], dcm[(0, 0)]);
    (roll, pitch, yaw)
}

impl F16Fsw {
    pub fn new() -> Self {
        Self {
            phase: F16Phase::Cruise,
            time: 0.0,
            break_start_time: 0.0,

            // Gains scaled for F-16 inertia: Ixx=12875, Iyy=75674, Izz=85552
            // For ~2 rad/s² angular accel at 1 rad error: need K ≈ I * 2
            // High D/P ratio (~1:1) for critical damping
            pitch_pid: PidController::pd(150000.0, 100000.0),
            roll_pid: PidController::pd(25000.0, 25000.0),

            pos: Vector3::new(0.0, 0.0, -F16_ALTITUDE),
            vel: Vector3::new(F16_SPEED, 0.0, 0.0),
            att: Quaternion::identity(),

            g_load: 1.0,
            altitude: F16_ALTITUDE,
            speed: F16_SPEED,
            range_to_missile: 3000.0,
            bank_angle_deg: 0.0,
        }
    }
}

impl FlightSoftware for F16Fsw {
    fn step(&mut self, input: &SensorInput) -> ActuatorCommands {
        let dt = input.dt;
        self.time = input.time;

        // --- Update nav from sensors ---
        if let Some(gps) = &input.sensors.gps {
            self.pos = gps.position;
            self.vel = gps.velocity;
        }
        if let Some(st) = &input.sensors.star_tracker {
            self.att = st.attitude;
        }
        let omega = input
            .sensors
            .imu
            .as_ref()
            .map(|i| i.angular_velocity)
            .unwrap_or_default();

        self.speed = self.vel.norm();
        self.altitude = -self.pos.z;

        let (roll, pitch, _yaw) = quaternion_to_euler(&self.att);
        self.bank_angle_deg = roll.to_degrees();

        // G-load from bank angle: in a coordinated turn, G = 1/cos(bank)
        // Cap at structural limit to avoid infinity near 90° bank
        let cos_bank = roll.cos().abs();
        self.g_load = if cos_bank > 0.11 { (1.0 / cos_bank).min(9.0) } else { 9.0 };

        // --- Radar ---
        for meas in &input.sensors.radar {
            if meas.detected {
                self.range_to_missile = meas.range;
            }
        }

        // --- Phase transitions ---
        match self.phase {
            F16Phase::Cruise => {
                // Break immediately on radar contact or at t=0.5s
                if self.range_to_missile < 3500.0 || self.time > 0.5 {
                    self.phase = F16Phase::BreakTurn;
                    self.break_start_time = self.time;
                }
            }
            F16Phase::BreakTurn => {
                if self.time - self.break_start_time > 12.0 {
                    self.phase = F16Phase::Extend;
                }
            }
            F16Phase::Extend => {}
        }

        // --- Control ---
        // Defensive break turn: bank hard INTO the missile (right, positive roll)
        // to maximize angular crossing rate. The missile starts behind and to our
        // right (east), so a right break forces maximum aspect angle change.
        //
        // Pull max AoA for highest G. At 80° bank, G ≈ 1/cos(80°) ≈ 5.8 base.
        // Higher AoA pushes G toward structural limit.

        let (target_roll, target_pitch, thrust) = match self.phase {
            F16Phase::Cruise => {
                let alt_error = F16_ALTITUDE - self.altitude;
                let pitch_cmd = 0.05 + (alt_error * 0.002).clamp(-0.05, 0.05);
                (0.0_f64, pitch_cmd, F16_THRUST_N * 0.4)
            }
            F16Phase::BreakTurn => {
                // Hard RIGHT bank into the threat — positive roll
                let target_bank = 80.0_f64.to_radians();

                // Aggressive AoA pull — ~13° for high-G near structural limit
                let target_pitch_rad = 0.23;

                // Altitude correction: pull harder if sinking
                let alt_error = F16_ALTITUDE - self.altitude;
                let alt_correction = (alt_error * 0.001).clamp(-0.02, 0.05);

                (target_bank, target_pitch_rad + alt_correction, F16_THRUST_N * 0.95)
            }
            F16Phase::Extend => {
                let alt_error = F16_ALTITUDE - self.altitude;
                let pitch_cmd = 0.06 + (alt_error * 0.002).clamp(-0.03, 0.05);
                (0.0, pitch_cmd, F16_THRUST_N * 0.85)
            }
        };

        // --- Attitude control ---
        let roll_error = target_roll - roll;
        let pitch_error = target_pitch - pitch;

        let roll_torque = self.roll_pid.step(&PidInput::with_derivative(roll_error, -omega.x), dt);
        let pitch_torque = self.pitch_pid.step(&PidInput::with_derivative(pitch_error, -omega.y), dt);
        let yaw_torque = -30000.0 * omega.z;

        let torque = Vector3::new(roll_torque, pitch_torque, yaw_torque);
        let max_torque = 200000.0;
        let torque = torque.map(|t| t.clamp(-max_torque, max_torque));

        ActuatorCommands {
            thrust: ThrustCommand {
                thrust,
                gimbal_pitch: 0.0,
                gimbal_yaw: 0.0,
            },
            torque: TorqueCommand { torque },
            ..ActuatorCommands::zero()
        }
    }

    fn is_complete(&self) -> bool {
        false
    }

    fn telemetry(&self) -> Vec<(&str, f64)> {
        vec![
            ("f16_phase", match self.phase {
                F16Phase::Cruise => 0.0,
                F16Phase::BreakTurn => 1.0,
                F16Phase::Extend => 2.0,
            }),
            ("f16_g_load", self.g_load),
            ("f16_altitude_m", self.altitude),
            ("f16_speed_mps", self.speed),
            ("f16_range_to_missile", self.range_to_missile),
            ("f16_bank_angle_deg", self.bank_angle_deg),
        ]
    }
}
