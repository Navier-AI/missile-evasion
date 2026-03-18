use nalgebra::Vector3;
use stellarust_core::{Quaternion, RigidBodyState};

// ============================================================
// F-16 Fighting Falcon
// ============================================================
pub const F16_MASS_KG: f64 = 12_000.0; // combat weight
pub const F16_THRUST_N: f64 = 76_000.0; // single F110 mil thrust
pub const F16_ISP_S: f64 = 3000.0; // jet engine effective Isp (large = low fuel rate)
pub const F16_FUEL_KG: f64 = 3000.0;
pub const F16_DRY_MASS_KG: f64 = 9_000.0;
pub const F16_IXX: f64 = 12_875.0; // kg*m^2 (roll)
pub const F16_IYY: f64 = 75_674.0; // kg*m^2 (pitch)
pub const F16_IZZ: f64 = 85_552.0; // kg*m^2 (yaw)
pub const F16_SPEED: f64 = 300.0; // ~Mach 0.9 at altitude [m/s]
pub const F16_ALTITUDE: f64 = 5000.0; // [m] (NED: -Z is up, so position Z = -5000)

// ============================================================
// AIM-9 Sidewinder-class missile
// ============================================================
pub const MISSILE_DRY_MASS_KG: f64 = 55.0;
pub const MISSILE_FUEL_MASS_KG: f64 = 35.0;
pub const MISSILE_THRUST_N: f64 = 12_700.0;
pub const MISSILE_ISP_S: f64 = 250.0;
pub const MISSILE_IXX: f64 = 0.5; // kg*m^2 (roll)
pub const MISSILE_IYY: f64 = 15.0; // kg*m^2 (pitch)
pub const MISSILE_IZZ: f64 = 15.0; // kg*m^2 (yaw)
pub const MISSILE_MAX_LATERAL_G: f64 = 30.0;

// Launch offset: missile starts 3 km behind and 500m to the right of the F-16
pub const MISSILE_OFFSET_X: f64 = 3000.0; // behind (positive X = aft in this setup)
pub const MISSILE_OFFSET_Y: f64 = 500.0; // to the east
pub const MISSILE_INITIAL_SPEED: f64 = 350.0; // launch platform speed + boost start

/// Create F-16 initial state in NED frame.
/// F-16 flies North (+X in NED) at 5000m altitude.
pub fn f16_initial_state() -> RigidBodyState {
    let mut state = RigidBodyState::with_diagonal_inertia(
        F16_MASS_KG, F16_IXX, F16_IYY, F16_IZZ,
    );
    // NED: X=North, Y=East, Z=Down.  Altitude 5000m means Z = -5000.
    state.position = Vector3::new(0.0, 0.0, -F16_ALTITUDE);
    // Flying north at Mach 0.9
    state.velocity = Vector3::new(F16_SPEED, 0.0, 0.0);
    // Level flight, nose pointing north: identity quaternion (body +X = NED +X = North)
    state.attitude = Quaternion::identity();
    state.angular_velocity = Vector3::zeros();
    state
}

/// Create Sidewinder initial state in NED frame.
/// Missile starts 3 km behind and 500m east of the F-16, heading north (pursuing).
pub fn missile_initial_state() -> RigidBodyState {
    let mut state = RigidBodyState::with_diagonal_inertia(
        MISSILE_DRY_MASS_KG + MISSILE_FUEL_MASS_KG,
        MISSILE_IXX, MISSILE_IYY, MISSILE_IZZ,
    );
    // Behind the F-16 (south) and offset east, same altitude
    state.position = Vector3::new(-MISSILE_OFFSET_X, MISSILE_OFFSET_Y, -F16_ALTITUDE);
    // Initially flying north toward the F-16
    state.velocity = Vector3::new(MISSILE_INITIAL_SPEED, 0.0, 0.0);
    state.attitude = Quaternion::identity();
    state.angular_velocity = Vector3::zeros();
    state
}
