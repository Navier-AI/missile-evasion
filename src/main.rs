mod f16_fsw;
mod missile_fsw;
mod vehicles;

use nalgebra::Vector3;
use stellarust_output::v2::{SceneRecorder, Visual};
use stellarust_output::CoordinateFrame;
use stellarust_sensors::{GpsConfig, ImuConfig, RadarConfig, SensorSuiteConfig, StarTrackerConfig};
use stellarust_sim::harness::{SimHarness, StepAction, VehicleConfig, VehicleSnapshot};
use stellarust_sim::GravityForce;
use stellarust_sim::propulsion::Engine;

use crate::f16_fsw::{F16Fsw, F16AeroForce};
use crate::missile_fsw::MissileFsw;
use crate::vehicles::*;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // ============================================================
    // Step 1: Physics predictions
    // ============================================================
    let g0 = 9.80665;

    // F-16 break turn parameters
    let turn_g = 7.5; // sustained G in break turn
    let turn_radius = F16_SPEED * F16_SPEED / (turn_g * g0);
    let turn_rate_dps = (F16_SPEED / turn_radius).to_degrees();

    // Missile parameters
    let mass_flow = MISSILE_THRUST_N / (MISSILE_ISP_S * g0);
    let burn_time = MISSILE_FUEL_MASS_KG / mass_flow;
    let missile_dv = MISSILE_ISP_S * g0 * ((MISSILE_DRY_MASS_KG + MISSILE_FUEL_MASS_KG) / MISSILE_DRY_MASS_KG).ln();
    let initial_range = (MISSILE_OFFSET_X * MISSILE_OFFSET_X + MISSILE_OFFSET_Y * MISSILE_OFFSET_Y).sqrt();
    let closing_speed = MISSILE_INITIAL_SPEED - F16_SPEED + missile_dv * 0.5; // rough average
    let time_to_intercept = initial_range / closing_speed;

    println!("=== MISSILE EVASION SIMULATION ===");
    println!();
    println!("F-16 Predictions:");
    println!("  Speed: {F16_SPEED:.0} m/s (Mach ~{:.2})", F16_SPEED / 340.0);
    println!("  Break turn G: {turn_g:.1} G");
    println!("  Turn radius: {turn_radius:.0} m");
    println!("  Turn rate: {turn_rate_dps:.1} deg/s");
    println!("  Altitude: {F16_ALTITUDE:.0} m");
    println!();
    println!("AIM-9 Sidewinder Predictions:");
    println!("  Burn time: {burn_time:.1} s");
    println!("  Delta-V: {missile_dv:.0} m/s");
    println!("  Max lateral: {:.0} G", MISSILE_MAX_LATERAL_G);
    println!("  Initial range: {initial_range:.0} m");
    println!("  Est. time to intercept (no evasion): {time_to_intercept:.1} s");
    println!();
    println!("Evasion goal: Break turn forces high angle-off, exceeding missile tracking capability.");
    println!();

    // ============================================================
    // Step 2: Vehicle configs
    // ============================================================

    // -- F-16 --
    let f16_state = f16_initial_state();
    let f16_sensors = SensorSuiteConfig {
        imu: Some(ImuConfig::default()),
        gps: Some(GpsConfig::default()),
        star_tracker: Some(StarTrackerConfig::default()),
        baro: None,
        horizon_sensor: None,
        rng_seed: 42,
    };
    let f16_engine = Engine::new(F16_THRUST_N, F16_ISP_S, F16_ISP_S);
    let f16_config = VehicleConfig::new("f16", f16_state, f16_sensors)
        .with_engine(f16_engine, F16_FUEL_KG, F16_DRY_MASS_KG)
        .with_radar(RadarConfig::default(), vec!["missile".into()])
        .with_color([0, 100, 255]);

    // -- Sidewinder Missile --
    let missile_state = missile_initial_state();
    let missile_sensors = SensorSuiteConfig {
        imu: Some(ImuConfig::default()),
        gps: Some(GpsConfig::default()),
        star_tracker: Some(StarTrackerConfig::default()),
        baro: None,
        horizon_sensor: None,
        rng_seed: 99,
    };
    let missile_engine = Engine::new(MISSILE_THRUST_N, MISSILE_ISP_S, MISSILE_ISP_S);
    let missile_config = VehicleConfig::new("missile", missile_state, missile_sensors)
        .with_engine(missile_engine, MISSILE_FUEL_MASS_KG, MISSILE_DRY_MASS_KG)
        .with_radar(RadarConfig::default(), vec!["f16".into()])
        .with_color([255, 50, 0]);

    // ============================================================
    // Step 3: Run simulation
    // ============================================================
    let max_time = 25.0;
    let kill_radius = 5.0; // meters

    let f16_fsw = F16Fsw::new();
    let missile_fsw = MissileFsw::new();

    let results = SimHarness::new(max_time)
        .with_physics_dt(0.001) // 1 kHz physics
        .with_control_dt(0.01) // 100 Hz FSW
        .with_record_interval(0.05) // 20 Hz telemetry
        .with_step_callback(move |_time, vehicles: &[VehicleSnapshot]| {
            let f16 = &vehicles[0];
            let missile = &vehicles[1];
            let range = (f16.state.position - missile.state.position).norm();
            if range < kill_radius {
                StepAction::Kill(vec!["f16".into()])
            } else {
                StepAction::Continue
            }
        })
        .add_vehicle_with_forces(f16_config, f16_fsw, vec![
            Box::new(GravityForce::flat(g0)),
            Box::new(F16AeroForce::new()),
        ])
        .add_vehicle_with_forces(missile_config, missile_fsw, vec![Box::new(GravityForce::flat(g0))])
        .run()
        .expect("simulation failed");

    // ============================================================
    // Step 4: Analyze results
    // ============================================================
    let recorder = results.recorder();

    // Compute min range (miss distance)
    let f16_times = recorder.times("f16");
    let f16_positions = recorder.positions("f16");
    let missile_positions = recorder.positions("missile");

    let mut min_range = f64::MAX;
    let mut min_range_time = 0.0;
    let n = f16_times.len().min(missile_positions.len());
    for i in 0..n {
        let f16_pos = Vector3::new(f16_positions[i][0], f16_positions[i][1], f16_positions[i][2]);
        let msl_pos = Vector3::new(missile_positions[i][0], missile_positions[i][1], missile_positions[i][2]);
        let range = (f16_pos - msl_pos).norm();
        if range < min_range {
            min_range = range;
            min_range_time = f16_times[i];
        }
    }

    println!("=== RESULTS ===");
    println!("  Simulation time: {:.1} s", results.final_time);
    println!("  Min range (miss distance): {min_range:.1} m at t={min_range_time:.2} s");
    if min_range < kill_radius {
        println!("  RESULT: MISSILE HIT - F-16 destroyed");
    } else {
        println!("  RESULT: MISSILE MISS - F-16 survived!");
        println!("  Evasion successful. Miss distance: {min_range:.1} m");
    }

    // Diagnostic: check F-16 flight parameters
    let f16_bank = recorder.channel("f16/f16_bank_angle_deg");
    let f16_gload = recorder.channel("f16/f16_g_load");
    let f16_alt = recorder.channel("f16/f16_altitude_m");
    let f16_spd = recorder.channel("f16/f16_speed_mps");
    if !f16_bank.is_empty() {
        let max_bank = f16_bank.iter().map(|&(_, v)| v.abs()).fold(0.0_f64, f64::max);
        let max_g = f16_gload.iter().map(|&(_, v)| v).fold(0.0_f64, f64::max);
        let min_alt = f16_alt.iter().map(|&(_, v)| v).fold(f64::MAX, f64::min);
        let max_alt = f16_alt.iter().map(|&(_, v)| v).fold(0.0_f64, f64::max);
        let min_spd = f16_spd.iter().map(|&(_, v)| v).fold(f64::MAX, f64::min);
        println!();
        println!("F-16 Flight Diagnostics:");
        println!("  Max bank angle: {max_bank:.1}°");
        println!("  Max G-load: {max_g:.1} G");
        println!("  Altitude range: {min_alt:.0} - {max_alt:.0} m");
        println!("  Min speed: {min_spd:.0} m/s");
    }

    // ============================================================
    // Step 5: Scene output
    // ============================================================
    let mut rec = SceneRecorder::new("F-16 Missile Evasion - Defensive Break Turn");
    rec.set_frame(CoordinateFrame::NED);

    // Entity setup
    rec.set_entity("f16", "F-16 Fighting Falcon")
        .color([0, 100, 255])
        .visual(Visual::Sphere {
            radius_m: 50.0,
        });

    rec.set_entity("missile", "AIM-9 Sidewinder")
        .color([255, 50, 0])
        .visual(Visual::Sphere {
            radius_m: 25.0,
        });

    // Log poses
    let f16_attitudes = recorder.attitudes("f16");
    for i in 0..f16_times.len() {
        rec.log_pose("f16", f16_times[i], f16_positions[i], Some(f16_attitudes[i]));
    }

    let missile_times = recorder.times("missile");
    let missile_attitudes = recorder.attitudes("missile");
    for i in 0..missile_times.len() {
        rec.log_pose(
            "missile",
            missile_times[i],
            missile_positions[i],
            Some(missile_attitudes[i]),
        );
    }

    // Log range between vehicles
    for i in 0..n {
        let f16_pos = Vector3::new(f16_positions[i][0], f16_positions[i][1], f16_positions[i][2]);
        let msl_pos = Vector3::new(missile_positions[i][0], missile_positions[i][1], missile_positions[i][2]);
        let range = (f16_pos - msl_pos).norm();
        rec.log_scalar_with_unit("f16", "range_to_missile", Some("m"), f16_times[i], range);
    }

    // Log FSW telemetry channels
    let f16_channels = [
        "f16_g_load",
        "f16_altitude_m",
        "f16_speed_mps",
        "f16_bank_angle_deg",
        "f16_phase",
    ];
    for ch in &f16_channels {
        let data = recorder.channel(&format!("f16/{ch}"));
        for &(t, val) in data {
            rec.log_scalar_with_unit("f16", ch, None, t, val);
        }
    }

    let missile_channels = [
        "missile_phase",
        "missile_range_to_target",
        "missile_closing_speed",
        "missile_time_to_go",
        "missile_lateral_accel_g",
        "missile_speed_mps",
        "missile_fuel_kg",
    ];
    for ch in &missile_channels {
        let data = recorder.channel(&format!("missile/{ch}"));
        for &(t, val) in data {
            rec.log_scalar_with_unit("missile", ch, None, t, val);
        }
    }

    // Chart hints
    rec.chart_hint("Engagement Range", &["range_to_missile", "missile_range_to_target"]);
    rec.chart_hint("F-16 Flight", &["f16_g_load", "f16_altitude_m", "f16_bank_angle_deg"]);
    rec.chart_hint("Missile Guidance", &["missile_closing_speed", "missile_lateral_accel_g", "missile_speed_mps"]);

    // Events
    rec.event(0.0, "Simulation Start");
    rec.event_for(min_range_time, &format!("Closest Approach: {min_range:.0}m"), "f16");
    if min_range >= kill_radius {
        rec.event_for(min_range_time, "MISSILE MISS", "missile");
    }

    let scene = rec.build().expect("valid scene");
    std::fs::create_dir_all("results")?;
    scene.write_bundle("results/evasion.stella")?;
    println!("\nResults written to results/evasion.stella");

    Ok(())
}
