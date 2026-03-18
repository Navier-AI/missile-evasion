// ============================================================
// GNC Algorithm Description Document (ADD)
// F-16 Missile Evasion — Defensive Break Turn
// Generated from STELLA telemetry bundle: evasion.stella
// ============================================================

#set document(
  title: "Algorithm Description Document — F-16 Missile Evasion",
  author: "Navier AI STELLA Agent",
)

#set page(
  paper: "us-letter",
  margin: (top: 1in, bottom: 1in, left: 1.25in, right: 1in),
  header: context {
    if counter(page).get().first() > 1 [
      #set text(size: 9pt, fill: gray)
      #grid(
        columns: (1fr, 1fr),
        align(left)[STELLA GNC ADD — F-16 Missile Evasion — #datetime.today().display()],
        align(right)[DISTRIBUTION: #text(fill: red)[TBD]]
      )
      #line(length: 100%, stroke: 0.5pt + gray)
    ]
  },
  footer: context [
    #set text(size: 9pt, fill: gray)
    #line(length: 100%, stroke: 0.5pt + gray)
    #grid(
      columns: (1fr, 1fr),
      align(left)[Navier AI Confidential],
      align(right)[Page #counter(page).display("1 of 1", both: true)]
    )
  ]
)

#set text(font: "New Computer Modern", size: 10pt)
#set heading(numbering: "1.1.1")
#show heading.where(level: 1): it => {
  v(0.8em)
  text(size: 13pt, weight: "bold")[#it]
  v(0.3em)
}
#show heading.where(level: 2): it => {
  v(0.5em)
  text(size: 11pt, weight: "bold")[#it]
  v(0.2em)
}

// ── TITLE PAGE ──────────────────────────────────────────────

#align(center)[
  #v(1.5in)
  #image("navier_logo.png", width: 2in)
  #v(0.5in)

  #text(size: 22pt, weight: "bold")[Algorithm Description Document]
  #v(0.2in)
  #text(size: 16pt)[F-16 Missile Evasion: Defensive Break Turn\ Against AIM-9 Sidewinder Engagement]
  #v(0.4in)

  #grid(
    columns: (auto, auto),
    gutter: 1em,
    align(right, text(weight: "bold")[Document Number:]),   [STELLA-ADD-0001],
    align(right, text(weight: "bold")[Revision:]),          [Rev A],
    align(right, text(weight: "bold")[Date:]),              [#datetime.today().display()],
    align(right, text(weight: "bold")[Classification:]),    text(fill: red)[[TBD --- CUI/ITAR assessment required]],
    align(right, text(weight: "bold")[Program:]),           [F-16 Survivability Analysis],
    align(right, text(weight: "bold")[Prepared by:]),       [Navier AI STELLA Agent],
    align(right, text(weight: "bold")[Reviewed by:]),       [[MANUAL: Engineer name]],
  )

  #v(0.5in)

  #rect(width: 90%, stroke: 1pt)[
    #table(
      columns: (1.2fr, 2fr, 1.5fr, 1.5fr),
      inset: 8pt,
      stroke: 0.5pt,
      fill: (col, row) => if row == 0 { luma(220) } else { white },
      [*Role*], [*Name*], [*Signature*], [*Date*],
      [*Prepared by*],  [Navier AI STELLA Agent],              [_Auto-generated_],     [#datetime.today().display()],
      [*Checked by*],   [[MANUAL: Checker name / title]],      [#line(length: 80%, stroke: 0.5pt)],     [#line(length: 80%, stroke: 0.5pt)],
      [*Approved by*],  [[MANUAL: Approver name / title]],     [#line(length: 80%, stroke: 0.5pt)],     [#line(length: 80%, stroke: 0.5pt)],
    )
  ]

  #v(0.4in)
  #rect(width: 90%, stroke: 1pt)[
    #pad(1em)[
      #text(weight: "bold")[NOTICE:] This document was generated automatically by the STELLA
      post-processing agent from simulation telemetry bundle #text(style: "italic")[evasion.stella].
      All numerical values are derived from simulation outputs. Checker and approver review
      required before use as a program deliverable. All sections marked #text(weight: "bold")[\[MANUAL\]]
      require engineer input prior to approval.
    ]
  ]
]

#pagebreak()

// ── REVISION HISTORY ────────────────────────────────────────

= Document Control

== Revision History

#table(
  columns: (auto, auto, 1fr, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Rev*], [*Date*], [*Description*], [*Author*],
  [A], [#datetime.today().display()], [Initial release --- auto-generated from STELLA bundle `evasion.stella`], [STELLA Agent],
  [],  [],            [],                                                       [],
)

== Applicable Documents

#table(
  columns: (auto, 1fr, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*ID*], [*Title*], [*Version*],
  [AD-01], [STELLA Framework Architecture Description], [v0.2.5],
  [AD-02], [stellarust-gnc: Augmented Proportional Navigation Reference], [v0.2.5],
  [AD-03], [stellarust-sim: Simulation Harness API], [v0.2.5],
  [AD-04], [[MANUAL: F-16 flight dynamics data source]], [],
  [AD-05], [[MANUAL: AIM-9 Sidewinder performance reference]], [],
)

#pagebreak()

// ── TABLE OF CONTENTS ───────────────────────────────────────

#outline(depth: 3, indent: auto)

#pagebreak()

// ── 1. INTRODUCTION ─────────────────────────────────────────

= Introduction

== Purpose

This document describes the guidance, navigation, and control (GNC) algorithms
implemented in the STELLA simulation framework for the
#text(style: "italic")[F-16 defensive break turn missile evasion] scenario.
It provides the mathematical basis, input/output interface definition, mode logic,
and simulation-derived performance characterization for both the evading fighter
aircraft (F-16 Fighting Falcon) and the pursuing missile (AIM-9 Sidewinder class).

The scenario evaluates whether a maximum-performance defensive break turn can
defeat an infrared-guided short-range air-to-air missile launched from the
rear hemisphere.

== Scope

This ADD covers the following algorithm functions:

- *F-16 Flight Control:* Cruise, Defensive Break Turn (high-G maneuver), and Extend phases
- *F-16 Aerodynamic Model:* Lift/drag polar with structural G-limiting
- *Missile Guidance:* Augmented Proportional Navigation (APN) with gimbal-steered thrust
- *Missile Flight Phases:* Boost, Terminal, and Expended states
- *Engagement Assessment:* Range computation, closest point of approach (CPA), hit/miss determination

The following are explicitly _out of scope_: [MANUAL: Electronic countermeasures (ECM/ECCM), multi-aircraft tactics, weapon system integration beyond kinematic simulation]

== Definitions and Acronyms

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt,
  [*Term*], [*Definition*],
  [ADD],    [Algorithm Description Document],
  [APN],    [Augmented Proportional Navigation],
  [CPA],    [Closest Point of Approach],
  [FSW],    [Flight Software],
  [GNC],    [Guidance, Navigation, and Control],
  [GPS],    [Global Positioning System],
  [IMU],    [Inertial Measurement Unit],
  [IR],     [Infrared],
  [LOS],    [Line of Sight],
  [NED],    [North-East-Down coordinate frame],
  [PD],     [Proportional-Derivative (controller)],
  [PID],    [Proportional-Integral-Derivative (controller)],
  [PN],     [Proportional Navigation],
  [STELLA], [Simulation Tool for Engagement-Level Lethality Analysis],
)

#pagebreak()

// ── 2. SYSTEM OVERVIEW ──────────────────────────────────────

= System Overview

== Engagement Configuration

This simulation models a tail-aspect infrared missile engagement against a
maneuvering fighter aircraft in the NED (North-East-Down) reference frame.
The F-16 detects the inbound missile via onboard radar and initiates a maximum-performance
defensive break turn to defeat the missile's guidance solution.

=== F-16 Fighting Falcon

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Parameter*], [*Value*],
  [Vehicle ID],            [`f16`],
  [Gross Mass],            [12,000 kg (combat weight)],
  [Dry Mass],              [9,000 kg],
  [Fuel Mass],             [3,000 kg],
  [Engine Thrust],         [76,000 N (F110-GE-100, military power)],
  [Wing Area],             [27.87 m²],
  [Moments of Inertia],    [$I_(x x) = 12,875$, $I_(y y) = 75,674$, $I_(z z) = 85,552$ kg·m²],
  [Initial Speed],         [300 m/s (Mach ~0.88)],
  [Initial Altitude],      [5,000 m MSL],
  [Initial Heading],       [North (NED +X)],
  [Structural G Limit],    [9.0 G],
  [Sensors],               [IMU, GPS, Star Tracker, Radar (tracking missile)],
)

=== AIM-9 Sidewinder Missile

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Parameter*], [*Value*],
  [Vehicle ID],            [`missile`],
  [Dry Mass],              [55 kg],
  [Fuel Mass],             [35 kg],
  [Total Mass at Launch],  [90 kg],
  [Motor Thrust],          [12,700 N],
  [Specific Impulse],      [250 s],
  [Estimated Burn Time],   [5.8 s],
  [Estimated Delta-V],     [1,207 m/s],
  [Max Lateral Accel],     [30 G (294.2 m/s²)],
  [Moments of Inertia],    [$I_(x x) = 0.5$, $I_(y y) = 15$, $I_(z z) = 15$ kg·m²],
  [Initial Speed],         [350 m/s],
  [Launch Offset],         [3,000 m aft, 500 m east of F-16],
  [Initial Range],         [3,041 m],
  [Sensors],               [IMU, GPS, Star Tracker, Radar (tracking F-16)],
)

#pagebreak()

== GNC Architecture

Both vehicles employ independent flight software (FSW) modules operating at 100 Hz,
with physics integrated at 1 kHz. Each FSW implements a phase-based finite state machine.

=== F-16 Phase State Machine

The F-16 FSW operates in three sequential phases:

+ *Cruise* (Phase 0): Level flight at 300 m/s, altitude hold via PD pitch control. Transitions to Break Turn upon radar detection of missile at range < 3,500 m or $t > 0.5$ s.
+ *Break Turn* (Phase 1): Maximum-performance right bank turn at 80° bank angle with aggressive angle-of-attack (~13°). Duration: 12 seconds. Designed to force high crossing angle against the missile.
+ *Extend* (Phase 2): Roll wings level and accelerate away from the engagement area with 85% throttle.

=== Missile Phase State Machine

The missile FSW operates in three phases:

+ *Boost* (Phase 0): Full-thrust motor burn with gimbal-steered thrust vector for guidance corrections. Duration: 5.8 s.
+ *Terminal* (Phase 1): Motor burnout; guidance continues via residual thrust (if fuel remains) and aerodynamic steering torques. Transitions to Expended if closing speed drops below $-100$ m/s after $t > 10$ s.
+ *Expended* (Phase 2): Guidance ceases; missile is ballistic.

#figure(
  image("charts/mode_timeline.png", width: 100%),
  caption: "Mission Phase Timeline — F-16 and AIM-9 Sidewinder"
)

#pagebreak()

// ── 3. F-16 FLIGHT CONTROL ALGORITHMS ───────────────────────

= F-16 Flight Control Algorithms

== Aerodynamic Force Model

The F-16 aerodynamic model computes lift and drag forces in the body frame,
then rotates them to the NED frame for integration.

=== Atmospheric Model

Density is computed using an exponential atmosphere:

$ rho(h) = rho_0 exp(-h / H) $

where $rho_0 = 1.225$ kg/m³ (sea-level density) and $H = 8500$ m (scale height).

=== Lift and Drag

Dynamic pressure:
$ q = 1/2 rho V^2 $

Lift coefficient (linear model, clamped at stall):
$ C_L = "clamp"(C_(L alpha) dot alpha, -C_(L,"max"), C_(L,"max")) $

Drag coefficient (parabolic polar):
$ C_D = C_(D 0) + C_L^2 / (pi e "AR") $

where:

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Parameter*], [*Value*], [*Units*],
  [$C_(L alpha)$], [3.44], [1/rad],
  [$C_(D 0)$], [0.025], [—],
  [$C_(L,"max")$], [1.2], [—],
  [Aspect Ratio (AR)], [3.2], [—],
  [Oswald factor ($e$)], [0.8], [—],
  [Wing area ($S$)], [27.87], [m²],
  [Structural G limit], [9.0], [G],
)

Lift force is clamped to enforce the structural G limit:
$ L_"max" = n_"limit" dot m dot g_0 = 9.0 times 12000 times 9.807 = 1.059 times 10^6 "N" $

=== Body-to-NED Rotation

Forces are computed in the body frame as $bold(F)_"body" = [-D, 0, -L]^T$ and
rotated to NED via the attitude quaternion:

$ bold(F)_"NED" = bold(q) circle.small bold(F)_"body" circle.small bold(q)^* $

#pagebreak()

== Attitude Control

=== Control Law

The F-16 employs PD attitude controllers for roll and pitch axes with yaw rate damping:

$ tau_"roll" = K_(p,"roll") (phi_"cmd" - phi) - K_(d,"roll") omega_x $
$ tau_"pitch" = K_(p,"pitch") (theta_"cmd" - theta) - K_(d,"pitch") omega_y $
$ tau_"yaw" = -K_(d,"yaw") omega_z $

=== Controller Gains

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Parameter*], [*Value*], [*Units*],
  [$K_(p,"roll")$], [25,000], [N·m/rad],
  [$K_(d,"roll")$], [25,000], [N·m·s/rad],
  [$K_(p,"pitch")$], [150,000], [N·m/rad],
  [$K_(d,"pitch")$], [100,000], [N·m·s/rad],
  [$K_(d,"yaw")$], [30,000], [N·m·s/rad],
  [Max torque (all axes)], [200,000], [N·m],
)

=== Phase-Specific Commands

#table(
  columns: (auto, auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Phase*], [*Bank Cmd*], [*Pitch Cmd*], [*Thrust*],
  [Cruise],     [0°],        [~2.9° + alt hold],  [40% (30,400 N)],
  [Break Turn], [80°],       [~13.2° + alt correction],  [95% (72,200 N)],
  [Extend],     [0°],        [~3.4° + alt hold],  [85% (64,600 N)],
)

=== Simulation Results — F-16 Flight Parameters

#figure(
  image("charts/f16_flight_params.png", width: 100%),
  caption: "F-16 Flight Parameters During Evasion Maneuver"
)

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Metric*], [*Value*], [*Notes*],
  [Max bank angle], [84.4°], [Target: 80°; slight overshoot],
  [Max G-load], [9.0 G], [At structural limit],
  [Altitude range], [4,993 -- 5,948 m], [Gained ~950 m during break],
  [Speed range], [269 -- 318 m/s], [Bled 31 m/s in turn],
  [Break turn duration], [12.0 s], [Commanded],
  [Break turn start], [$t = 0.05$ s], [Immediate upon radar contact],
)

#pagebreak()

// ── 4. MISSILE GUIDANCE ALGORITHMS ──────────────────────────

= Missile Guidance Algorithms

== Augmented Proportional Navigation

=== Algorithm Description

The missile employs Augmented Proportional Navigation (APN), a standard
homing guidance law that commands lateral acceleration proportional to
the line-of-sight (LOS) rotation rate and closing velocity:

$ bold(a)_"cmd" = N' dot V_c dot bold(Omega)_"LOS" $

where $N'$ is the effective navigation constant, $V_c$ is the closing velocity
(range rate), and $bold(Omega)_"LOS"$ is the angular rate of the LOS vector.

=== Guidance Parameters

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Parameter*], [*Value*], [*Units*],
  [Navigation constant ($N'$)], [4.0], [—],
  [Max lateral acceleration], [294.2 (30 G)], [m/s²],
  [Max axial acceleration], [50.0], [m/s²],
  [Min active range], [10.0], [m],
  [Adaptive mode], [Off], [—],
)

== Steering Implementation

=== Velocity Vector Tracking

The missile body tracks its velocity vector via PD torque control,
preventing body wobble from rapid reorientation. The velocity direction in
body frame is computed and errors around pitch (Y) and yaw (Z) axes are driven
to zero:

$ tau_"pitch" = k_p (-v_(z,"body")) - k_d omega_y $
$ tau_"yaw" = k_p (v_(y,"body")) - k_d omega_z $
$ tau_"roll" = -k_(d,"roll") omega_x $

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Parameter*], [*Value*], [*Units*],
  [$k_p$ (steering)], [100], [N·m/rad],
  [$k_d$ (steering)], [30], [N·m·s/rad],
  [$k_(d,"roll")$], [20], [N·m·s/rad],
)

=== Thrust Gimbal

During boost phase, guidance corrections are applied via thrust vector control
(gimbal pitch and yaw), with gimbal limits of $plus.minus 0.3$ rad (17.2°)
during boost and $plus.minus 0.5$ rad (28.6°) during terminal phase.
The gimbal angles are computed by projecting the desired acceleration vector
into body frame:

$ delta_"pitch" = "clamp"("atan2"(-a_(z,"body"), a_(x,"body")), -delta_"max", delta_"max") $
$ delta_"yaw" = "clamp"("atan2"(a_(y,"body"), a_(x,"body")), -delta_"max", delta_"max") $

== Target Tracking

The missile reconstructs target position from radar measurements (range, azimuth,
elevation) and estimates target velocity from successive position updates:

$ bold(r)_"target" = bold(r)_"own" + hat(bold(u))_"LOS" dot R $

$ bold(v)_"target" approx (bold(r)_"target"(t) - bold(r)_"target"(t - Delta t)) / Delta t $

#pagebreak()

== Flight Phase Performance

=== Phase Timing

#table(
  columns: (auto, auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Phase*], [*Start*], [*End*], [*Duration*],
  [Boost],      [$t = 0.05$ s], [$t = 5.85$ s], [5.80 s],
  [Terminal],   [$t = 5.85$ s], [$t = 10.05$ s], [4.20 s],
  [Expended],   [$t = 10.05$ s], [$t = 25.0$ s], [14.95 s],
)

=== Missile Guidance Telemetry

#figure(
  image("charts/missile_guidance_params.png", width: 100%),
  caption: "AIM-9 Sidewinder Guidance Parameters During Engagement"
)

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Metric*], [*Value*], [*Notes*],
  [Peak speed], [1,310 m/s], [Mach ~3.9 at end of boost],
  [Max closing speed], [556 m/s], [During initial approach],
  [Max lateral accel], [30.0 G], [At guidance limit],
  [Final fuel remaining], [4.6 kg], [Terminal phase used residual thrust],
  [Phase at simulation end], [Expended], [Diverging from target],
)

#pagebreak()

// ── 5. ENGAGEMENT ANALYSIS ──────────────────────────────────

= Engagement Analysis

== Engagement Geometry

The missile launches from the rear quarter of the F-16 (3,000 m aft, 500 m east)
at $t = 0$. The F-16 immediately initiates a hard right break turn at 80° bank,
pulling 9 G. This forces a rapidly increasing crossing angle, driving up the
LOS rotation rate faster than the missile's lateral acceleration can track.

#figure(
  image("charts/engagement_geometry.png", width: 100%),
  caption: "Engagement Geometry — Top-Down View (NED Frame)"
)

== Range Profile

#figure(
  image("charts/range_vs_time.png", width: 100%),
  caption: "F-16 to Missile Range vs. Time"
)

The range decreases from 3,041 m at $t = 0$ to a minimum of *239.1 m* at $t = 6.05$ s
(closest point of approach). After CPA, the range monotonically increases as the
missile's energy is insufficient to re-engage.

== Closing Geometry

#figure(
  image("charts/closing_geometry.png", width: 100%),
  caption: "Missile Closing Speed and Range to Target"
)

#pagebreak()

== 3D Trajectory

#figure(
  image("charts/trajectory_3d.png", width: 100%),
  caption: "3D Engagement Trajectory — F-16 and AIM-9 Sidewinder"
)

== Altitude Profiles

#figure(
  image("charts/altitude_profiles.png", width: 100%),
  caption: "Altitude Profiles — F-16 vs AIM-9 Sidewinder"
)

The F-16's break turn causes a climb from 5,000 m to approximately 5,950 m as the
high bank angle and aggressive pitch command produce a vertical lift component.
The missile initially tracks at the same altitude but diverges as it expends energy
attempting to match the F-16's lateral maneuver.

#pagebreak()

== Engagement Summary

#table(
  columns: (auto, auto),
  inset: 8pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Metric*], [*Value*],
  [*Outcome*],              [*MISSILE MISS — F-16 survived*],
  [Miss distance (CPA)],    [239.1 m],
  [Time of CPA],            [$t = 6.05$ s],
  [Kill radius],            [5.0 m],
  [Miss margin],            [234.1 m (47× kill radius)],
  [Initial range],          [3,041 m],
  [Simulation duration],    [25.0 s],
  [F-16 final state],       [Wings level, extending at 285 m/s],
  [Missile final state],    [Expended, diverging],
)

#pagebreak()

// ── 6. MODE TRANSITION TIMELINE ─────────────────────────────

= Mission Timeline and Mode Transitions

#figure(
  image("charts/mode_timeline.png", width: 100%),
  caption: "GNC Mode Transition Timeline — All Vehicles"
)

#table(
  columns: (auto, auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*T (s)*], [*Vehicle*], [*Event / Transition*], [*Notes*],
  [0.00], [Both], [Simulation Start], [Engagement initiated],
  [0.05], [F-16], [Cruise → Break Turn], [Radar detects missile],
  [0.05], [Missile], [Boost phase begins], [Motor ignition],
  [5.85], [Missile], [Boost → Terminal], [Motor burnout; 4.6 kg fuel remaining],
  [6.05], [F-16], [Closest Approach: 239 m], [CPA — missile misses],
  [6.05], [Missile], [MISSILE MISS], [Beyond kill radius (5 m)],
  [10.05], [Missile], [Terminal → Expended], [Closing speed < $-100$ m/s; guidance ceases],
  [12.05], [F-16], [Break Turn → Extend], [12 s turn complete; wings level],
  [25.00], [Both], [Simulation End], [],
)

#pagebreak()

// ── 7. ERROR BUDGET AND SENSITIVITY ─────────────────────────

= Error Budget and Sensitivity Analysis

== Sensor Configuration

Both vehicles use default STELLA sensor configurations:

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Sensor*], [*Configuration*], [*Notes*],
  [IMU], [Default ImuConfig], [Gyro + accelerometer noise],
  [GPS], [Default GpsConfig], [Position + velocity measurements],
  [Star Tracker], [Default StarTrackerConfig], [Attitude quaternion measurement],
  [Radar], [Default RadarConfig], [Range, range-rate, azimuth, elevation],
)

== Key Sensitivities

The engagement outcome (miss distance) is sensitive to the following parameters.
A full Monte Carlo sensitivity analysis is recommended (see Section 9):

#table(
  columns: (auto, 1fr, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Parameter*], [*Expected Impact*], [*Priority*],
  [F-16 break turn timing], [Earlier break increases miss; delayed break decreases miss], [High],
  [F-16 bank angle command], [Higher bank = higher crossing rate = larger miss], [High],
  [Missile navigation constant ($N'$)], [Higher $N'$ improves tracking of maneuvering targets], [High],
  [Missile max lateral G], [Higher G limit allows tighter turns], [High],
  [Initial range], [Shorter range gives missile less time to lose energy], [Medium],
  [F-16 speed at break initiation], [Higher speed = tighter turn at same G], [Medium],
  [Radar noise / latency], [Degrades missile target estimation], [Low],
)

== Gravity Model

Both vehicles use a flat-gravity model ($g = 9.80665$ m/s², downward) appropriate
for the engagement altitude range (5,000--6,000 m) and short duration (25 s).
No J2, EGM2008, or centrifugal corrections are applied.

#pagebreak()

// ── 8. VERIFICATION AND VALIDATION ──────────────────────────

= Verification and Validation

== Simulation Configuration

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt,
  [*Parameter*], [*Value*],
  [STELLA version],         [stellarust v0.2.5],
  [Physics rate],           [1,000 Hz (dt = 0.001 s)],
  [FSW rate],               [100 Hz (dt = 0.01 s)],
  [Telemetry record rate],  [20 Hz (interval = 0.05 s)],
  [Simulation duration],    [25.0 s],
  [Number of vehicles],     [2 (F-16, AIM-9)],
  [Coordinate frame],       [NED (North-East-Down)],
  [Bundle format],          [v2 (.stella directory with parquet)],
  [Bundle ID],              [`evasion.stella`],
)

== Test Cases

#table(
  columns: (auto, 1fr, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*ID*], [*Description*], [*Expected*], [*Result*],
  [TC-01], [Missile misses F-16 (CPA > kill radius)],    [CPA > 5 m], [*PASS* (239.1 m)],
  [TC-02], [F-16 achieves target bank angle],             [Bank ≥ 75°], [*PASS* (84.4°)],
  [TC-03], [F-16 G-load within structural limit],         [G ≤ 9.0],   [*PASS* (9.0 G)],
  [TC-04], [F-16 maintains positive altitude],             [Alt > 0 m], [*PASS* (min 4,993 m)],
  [TC-05], [Missile achieves boost phase burnout],         [Burn ≈ 5.8 s], [*PASS* (5.80 s)],
  [TC-06], [Missile guidance saturates (max lateral G)],   [Lat G = 30], [*PASS* (30.0 G observed)],
  [TC-07], [Missile transitions to Expended on divergence], [Phase = 2 after diverge], [*PASS* ($t = 10.05$ s)],
  [TC-08], [Simulation completes without numerical errors], [No NaN/Inf], [*PASS*],
)

#pagebreak()

// ── 9. KNOWN LIMITATIONS ────────────────────────────────────

= Known Limitations and Open Items

#table(
  columns: (auto, 1fr, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*ID*], [*Description*], [*Status*],
  [LIM-01], [Single-run deterministic simulation --- Monte Carlo analysis pending for statistical confidence on miss distance], [Open],
  [LIM-02], [Flat gravity model ($g$ = const) --- acceptable for short-duration, low-altitude engagement], [Accepted],
  [LIM-03], [Exponential atmosphere model --- NRLMSISE-00 or US Standard Atmosphere not implemented], [Open],
  [LIM-04], [No aerodynamic drag model on missile --- drag forces not modeled, only thrust and gravity], [Open],
  [LIM-05], [Simplified F-16 aero: no sideslip, no compressibility effects, no control surface deflection limits], [Open],
  [LIM-06], [Star tracker sensor unrealistic for air-to-air scenario --- used as generic attitude sensor], [Accepted],
  [LIM-07], [Radar model provides perfect azimuth/elevation --- no angle noise or track jitter], [Open],
  [LIM-08], [No missile seeker model (IR/RF) --- radar-based tracking instead of realistic IR seeker cone], [Open],
  [LIM-09], [No pilot model --- F-16 FSW executes pre-programmed maneuver without decision logic], [Accepted],
  [LIM-10], [First telemetry sample contains NaN for some channels (initialization artifact)], [Accepted],
)

#pagebreak()

// ── 10. REFERENCES ──────────────────────────────────────────

= References

+ Zarchan, P., _Tactical and Strategic Missile Guidance_, 7th ed., AIAA, 2019.
+ Stevens, B.L. and Lewis, F.L., _Aircraft Control and Simulation_, 3rd ed., Wiley, 2015.
+ Siouris, G.M., _Missile Guidance and Control Systems_, Springer, 2004.
+ Yanushevsky, R., _Modern Missile Guidance_, CRC Press, 2008.
+ [MANUAL: F-16 flight performance data source / NATOPS equivalent]
+ [MANUAL: AIM-9 Sidewinder unclassified performance reference]
+ [MANUAL: Program-specific requirements documents]

// ── APPENDIX ────────────────────────────────────────────────

#pagebreak()

= Appendix A: Telemetry Channel Definitions

== F-16 Channels

#table(
  columns: (auto, auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Channel*], [*Units*], [*Description*],
  [`f16_phase`], [—], [FSW phase: 0=Cruise, 1=BreakTurn, 2=Extend],
  [`f16_g_load`], [G], [Normal load factor from bank angle: $1/"cos"(phi)$],
  [`f16_altitude_m`], [m], [Altitude above sea level ($-z$ in NED)],
  [`f16_speed_mps`], [m/s], [Total airspeed (velocity magnitude)],
  [`f16_bank_angle_deg`], [deg], [Roll angle extracted from attitude quaternion],
  [`range_to_missile`], [m], [Radar-measured range to missile entity],
)

== Missile Channels

#table(
  columns: (auto, auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Channel*], [*Units*], [*Description*],
  [`missile_phase`], [—], [FSW phase: 0=Boost, 1=Terminal, 2=Expended],
  [`missile_range_to_target`], [m], [Computed range to F-16],
  [`missile_closing_speed`], [m/s], [Range rate (positive = closing)],
  [`missile_time_to_go`], [s], [Estimated time to intercept from guidance],
  [`missile_lateral_accel_g`], [G], [Commanded lateral acceleration magnitude],
  [`missile_speed_mps`], [m/s], [Total missile speed],
  [`missile_fuel_kg`], [kg], [Remaining propellant mass],
)

#pagebreak()

= Appendix B: Engagement Geometry Detail

#figure(
  image("charts/engagement_geometry.png", width: 95%),
  caption: "Top-down engagement geometry with time annotations"
)

#figure(
  image("charts/trajectory_3d.png", width: 95%),
  caption: "3D trajectory showing altitude separation"
)
