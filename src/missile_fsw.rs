use nalgebra::Vector3;
use stellarust_core::system::{ThrustCommand, TorqueCommand};
use stellarust_core::{Quaternion, System};
use stellarust_gnc::{AugmentedPN, GuidanceConfig, GuidanceInput};
use stellarust_sim::harness::{ActuatorCommands, FlightSoftware, SensorInput};

use crate::vehicles::*;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum MissilePhase {
    Boost,
    Terminal,
    Expended,
}

pub struct MissileFsw {
    phase: MissilePhase,
    guidance: AugmentedPN,
    time: f64,
    burn_time: f64,

    // Cached nav state
    own_pos: Vector3<f64>,
    own_vel: Vector3<f64>,
    att: Quaternion,
    target_pos: Vector3<f64>,
    target_vel: Vector3<f64>,
    prev_target_pos: Vector3<f64>,
    prev_target_time: f64,
    has_radar_lock: bool,

    // Telemetry
    range_to_target: f64,
    closing_speed: f64,
    time_to_go: f64,
    lateral_accel_cmd: f64,
    missile_speed: f64,
    fuel_remaining: f64,
}

impl MissileFsw {
    pub fn new() -> Self {
        let guidance_config = GuidanceConfig {
            navigation_constant: 4.0,
            max_lateral_accel: MISSILE_MAX_LATERAL_G * 9.80665,
            max_axial_accel: 50.0,
            min_active_range: 10.0,
            adaptive: false,
            ..Default::default()
        };

        let burn_time = 5.8;

        Self {
            phase: MissilePhase::Boost,
            guidance: AugmentedPN::with_config(guidance_config),
            time: 0.0,
            burn_time,
            own_pos: Vector3::new(-MISSILE_OFFSET_X, MISSILE_OFFSET_Y, -F16_ALTITUDE),
            own_vel: Vector3::new(MISSILE_INITIAL_SPEED, 0.0, 0.0),
            att: Quaternion::identity(),
            target_pos: Vector3::new(0.0, 0.0, -F16_ALTITUDE),
            target_vel: Vector3::new(F16_SPEED, 0.0, 0.0),
            prev_target_pos: Vector3::new(0.0, 0.0, -F16_ALTITUDE),
            prev_target_time: 0.0,
            has_radar_lock: false,
            range_to_target: 3000.0,
            closing_speed: 0.0,
            time_to_go: 10.0,
            lateral_accel_cmd: 0.0,
            missile_speed: MISSILE_INITIAL_SPEED,
            fuel_remaining: MISSILE_FUEL_MASS_KG,
        }
    }
}

impl FlightSoftware for MissileFsw {
    fn step(&mut self, input: &SensorInput) -> ActuatorCommands {
        let dt = input.dt;
        self.time = input.time;

        // --- Update own state from sensors ---
        if let Some(gps) = &input.sensors.gps {
            self.own_pos = gps.position;
            self.own_vel = gps.velocity;
        }
        if let Some(st) = &input.sensors.star_tracker {
            self.att = st.attitude;
        }
        self.missile_speed = self.own_vel.norm();
        if let Some(prop) = &input.propulsion {
            self.fuel_remaining = prop.propellant_mass_kg;
        }

        // --- Update target from radar ---
        // Radar gives range, range_rate, azimuth, elevation in inertial frame.
        // Reconstruct target position from LOS + range.
        // Estimate target velocity from successive position measurements.
        for meas in &input.sensors.radar {
            if meas.detected {
                let az = meas.azimuth.unwrap_or(0.0);
                let el = meas.elevation.unwrap_or(0.0);
                let los = Vector3::new(
                    az.cos() * el.cos(),
                    az.sin() * el.cos(),
                    el.sin(),
                );

                let new_target_pos = self.own_pos + los * meas.range;

                // Estimate target velocity from position change over time
                let dt_radar = self.time - self.prev_target_time;
                if self.has_radar_lock && dt_radar > 0.001 {
                    self.target_vel = (new_target_pos - self.prev_target_pos) / dt_radar;
                }

                self.prev_target_pos = self.target_pos;
                self.prev_target_time = self.time;
                self.target_pos = new_target_pos;
                self.has_radar_lock = true;
            }
        }

        // Compute geometry
        let rel_pos = self.target_pos - self.own_pos;
        self.range_to_target = rel_pos.norm();
        let rel_vel = self.target_vel - self.own_vel;
        if self.range_to_target > 1.0 {
            let los = rel_pos / self.range_to_target;
            self.closing_speed = -rel_vel.dot(&los);
        }

        // --- Phase transitions ---
        match self.phase {
            MissilePhase::Boost => {
                if self.time > self.burn_time {
                    self.phase = MissilePhase::Terminal;
                }
            }
            MissilePhase::Terminal => {
                // Expend if diverging for a while
                if self.closing_speed < -100.0 && self.time > 10.0 {
                    self.phase = MissilePhase::Expended;
                }
            }
            MissilePhase::Expended => {}
        }

        // --- Guidance ---
        let guidance_input = GuidanceInput {
            interceptor_pos: self.own_pos,
            interceptor_vel: self.own_vel,
            target_pos: self.target_pos,
            target_vel: self.target_vel,
            target_accel: None,
            time: self.time,
        };
        let cmd = self.guidance.step(&guidance_input, dt);
        self.time_to_go = cmd.time_to_go;
        self.lateral_accel_cmd = if cmd.active { cmd.acceleration.norm() } else { 0.0 };

        // --- Compute steering ---
        // The missile body should track its velocity vector (aerodynamic weathervaning).
        // Guidance corrections are applied via thrust gimbal, not body rotation.
        // This prevents the wobble caused by rapid body reorientation.
        let desired_inertial_dir = if self.missile_speed > 10.0 {
            self.own_vel / self.missile_speed
        } else {
            Vector3::x()
        };

        // Convert desired direction to body frame error
        let body_desired = self.att.conjugate().rotate(&desired_inertial_dir);
        // body_desired should ideally be [1, 0, 0] (body +X)
        // Error: rotation needed around Y (pitch) and Z (yaw) axes
        let pitch_error = -body_desired.z; // need to pitch up if target is below body X
        let yaw_error = body_desired.y;    // need to yaw right if target is right of body X

        // Get angular velocity for derivative term
        let omega = input
            .sensors
            .imu
            .as_ref()
            .map(|i| i.angular_velocity)
            .unwrap_or_default();

        // PD steering — smooth velocity-vector tracking
        let kp_steer = 100.0;
        let kd_steer = 30.0;
        let pitch_torque = kp_steer * pitch_error - kd_steer * omega.y;
        let yaw_torque = kp_steer * yaw_error - kd_steer * omega.z;
        // Roll damping only
        let roll_torque = -20.0 * omega.x;

        let steer_torque = Vector3::new(roll_torque, pitch_torque, yaw_torque);

        match self.phase {
            MissilePhase::Boost => {
                // Gimbal steers thrust toward guidance-commanded direction
                let (gp, gy) = if cmd.active && cmd.acceleration.norm() > 1.0 {
                    let desired_thrust_dir = cmd.acceleration.normalize();
                    let body_desired = self.att.conjugate().rotate(&desired_thrust_dir);
                    let gp = libm::atan2(-body_desired.z, body_desired.x).clamp(-0.3, 0.3);
                    let gy = libm::atan2(body_desired.y, body_desired.x).clamp(-0.3, 0.3);
                    (gp, gy)
                } else {
                    (0.0, 0.0)
                };

                ActuatorCommands {
                    thrust: ThrustCommand {
                        thrust: MISSILE_THRUST_N,
                        gimbal_pitch: gp,
                        gimbal_yaw: gy,
                    },
                    torque: TorqueCommand { torque: steer_torque },
                    ..ActuatorCommands::zero()
                }
            }
            MissilePhase::Terminal => {
                let has_fuel = self.fuel_remaining > 0.1;
                if cmd.active && has_fuel {
                    let mass = MISSILE_DRY_MASS_KG + self.fuel_remaining;
                    let needed_force = cmd.acceleration.norm() * mass;
                    let terminal_thrust = needed_force.min(MISSILE_THRUST_N * 0.3);

                    let desired_thrust_dir = cmd.acceleration.normalize();
                    let body_desired = self.att.conjugate().rotate(&desired_thrust_dir);
                    let gp = libm::atan2(-body_desired.z, body_desired.x).clamp(-0.5, 0.5);
                    let gy = libm::atan2(body_desired.y, body_desired.x).clamp(-0.5, 0.5);

                    ActuatorCommands {
                        thrust: ThrustCommand {
                            thrust: terminal_thrust,
                            gimbal_pitch: gp,
                            gimbal_yaw: gy,
                        },
                        torque: TorqueCommand { torque: steer_torque },
                        ..ActuatorCommands::zero()
                    }
                } else {
                    // No fuel: torque-only steering (aerodynamic fins would do this)
                    ActuatorCommands {
                        thrust: ThrustCommand { thrust: 0.0, gimbal_pitch: 0.0, gimbal_yaw: 0.0 },
                        torque: TorqueCommand { torque: steer_torque },
                        ..ActuatorCommands::zero()
                    }
                }
            }
            MissilePhase::Expended => ActuatorCommands::zero(),
        }
    }

    fn is_complete(&self) -> bool {
        self.phase == MissilePhase::Expended
    }

    fn telemetry(&self) -> Vec<(&str, f64)> {
        vec![
            ("missile_phase", match self.phase {
                MissilePhase::Boost => 0.0,
                MissilePhase::Terminal => 1.0,
                MissilePhase::Expended => 2.0,
            }),
            ("missile_range_to_target", self.range_to_target),
            ("missile_closing_speed", self.closing_speed),
            ("missile_time_to_go", self.time_to_go),
            ("missile_lateral_accel_g", self.lateral_accel_cmd / 9.80665),
            ("missile_speed_mps", self.missile_speed),
            ("missile_fuel_kg", self.fuel_remaining),
        ]
    }
}
