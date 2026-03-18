// ============================================================
// GNC Algorithm Description Document (ADD) — Typst Template
// Navier AI / STELLA Simulation Framework
// ============================================================
// Usage: Pass this file as context to the STELLA post-processing
// agent along with a .stella telemetry bundle. The agent should
// populate all sections marked [AUTO] from telemetry data, and
// leave [MANUAL] sections for engineer review.
// ============================================================

#set document(
  title: "Algorithm Description Document",
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
        align(left)[STELLA GNC ADD — #datetime.today().display()],
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
  #image("navier_logo.png", width: 2in) // optional
  #v(0.5in)

  #text(size: 22pt, weight: "bold")[Algorithm Description Document]
  #v(0.2in)
  #text(size: 16pt)[[ALGORITHM NAME — e.g., "SDA Tracking Layer GNC: Threat Detection and Attitude Control"]]
  #v(0.4in)

  #grid(
    columns: (auto, auto),
    gutter: 1em,
    align(right, text(weight: "bold")[Document Number:]),   [STELLA-ADD-[XXXX]],
    align(right, text(weight: "bold")[Revision:]),          [Rev A],
    align(right, text(weight: "bold")[Date:]),              [[AUTO: simulation epoch]],
    align(right, text(weight: "bold")[Classification:]),    text(fill: red)[[TBD — CUI/ITAR assessment required]],
    align(right, text(weight: "bold")[Program:]),           [[e.g., SDA PWSA Tracking Layer]],
    align(right, text(weight: "bold")[Prepared by:]),       [Navier AI STELLA Agent],
    align(right, text(weight: "bold")[Reviewed by:]),       [[MANUAL: Engineer name]],
  )

  #v(0.5in)
  #rect(width: 90%, stroke: 1pt)[
    #pad(1em)[
      #text(weight: "bold")[NOTICE:] This document was generated automatically by the STELLA
      post-processing agent from simulation telemetry bundle #text(style: "italic")[[AUTO: bundle ID]].
      All numerical values are derived from simulation outputs. Engineer review required
      before use as a program deliverable.
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
  [A], [[AUTO: date]], [Initial release — auto-generated from STELLA bundle], [STELLA Agent],
  [],  [],            [],                                                       [],
)

== Applicable Documents

#table(
  columns: (auto, 1fr, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*ID*], [*Title*], [*Version*],
  [AD-01], [STELLA Framework Architecture Description], [current],
  [AD-02], [SDA PWSA Interface Control Document], [[MANUAL]],
  [AD-03], [EGM2008 Gravitational Model], [2008],
  [AD-04], [[MANUAL: additional program docs]], [],
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
#text(style: "italic")[[AUTO: vehicle/mission name]] mission.
It provides the mathematical basis, input/output interface definition, mode logic,
and simulation-derived performance characterization required for algorithm
review and program documentation.

== Scope

This ADD covers the following algorithm functions:

- [AUTO: list modes/algorithms from telemetry, e.g., "Detumble", "NadirPointing", "SlewToTrack", "Tracking", "ReturnToNadir"]

The following are explicitly _out of scope_: [MANUAL]

== Definitions and Acronyms

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt,
  [*Term*], [*Definition*],
  [ADD],    [Algorithm Description Document],
  [ECI],    [Earth-Centered Inertial frame],
  [ECEF],   [Earth-Centered Earth-Fixed frame],
  [EKF],    [Extended Kalman Filter],
  [FSW],    [Flight Software],
  [GNC],    [Guidance, Navigation, and Control],
  [OPIR],   [Overhead Persistent Infrared],
  [PWSA],   [Proliferated Warfighter Space Architecture],
  [SDA],    [Space Development Agency],
  [SITL],   [Software-in-the-Loop],
  [SNR],    [Signal-to-Noise Ratio],
  [[AUTO: add from telemetry bundle metadata]], [],
)

#pagebreak()

// ── 2. SYSTEM OVERVIEW ──────────────────────────────────────

= System Overview

== Vehicle Configuration

// [AUTO: populate from scenario config in .stella bundle]

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Parameter*], [*Value*],
  [Vehicle ID],          [[AUTO]],
  [Orbit Altitude],      [[AUTO] km],
  [Inclination],         [[AUTO]°],
  [Dry Mass],            [[AUTO] kg],
  [Moments of Inertia],  [Ixx=[AUTO], Iyy=[AUTO], Izz=[AUTO] kg·m²],
  [Actuators],           [[AUTO: e.g., reaction wheels, thrusters]],
  [Sensors],             [[AUTO: e.g., star tracker, GPS, IMU]],
  [Payload FOV],         [[AUTO]° half-angle],
)

== GNC Architecture

// [AUTO: describe the mode state machine derived from telemetry mode transitions]

The GNC system is structured as a finite state machine with the following modes:

// [AUTO: generate from observed mode_id transitions in telemetry]

#figure(
  rect(width: 100%, height: 3in, stroke: 1pt)[
    #align(center + horizon)[_[AUTO: mode transition diagram — generate from telemetry mode_id column]_]
  ],
  caption: "GNC Mode State Machine"
)

#pagebreak()

// ── 3. NAVIGATION ALGORITHMS ────────────────────────────────

= Navigation Algorithms

== State Estimation: Extended Kalman Filter

=== State Vector

The navigation filter maintains the following state vector:

$ bold(x) = [bold(r)^T, bold(v)^T, bold(q)^T, bold(b)_omega^T, bold(b)_a^T]^T $

where $bold(r) in RR^3$ is position in ECI (m), $bold(v) in RR^3$ is velocity (m/s),
$bold(q) in RR^4$ is the attitude quaternion (body-to-ECI), $bold(b)_omega in RR^3$
is gyro bias (rad/s), and $bold(b)_a in RR^3$ is accelerometer bias (m/s²).

=== Process Model

// [MANUAL: fill in specific dynamics model used — J2, EGM2008, etc.]

=== Measurement Models

// [AUTO: populate from sensor_config in .stella bundle]

*Star Tracker:*
$ bold(z)_"ST" = bold(q)_"meas" + bold(nu)_"ST", quad bold(nu)_"ST" ~ cal(N)(0, bold(R)_"ST") $

*GPS:*
$ bold(z)_"GPS" = bold(r)_"true" + bold(nu)_"GPS", quad bold(nu)_"GPS" ~ cal(N)(0, bold(R)_"GPS") $

*IMU:*
$ tilde(bold(omega)) = bold(omega)_"true" + bold(b)_omega + bold(nu)_omega $

=== Filter Performance (Simulation Results)

// [AUTO: compute from nav_error channel in telemetry bundle]

#figure(
  rect(width: 100%, height: 2.5in, stroke: 1pt)[
    #align(center + horizon)[_[AUTO: position error norm vs. time plot]_]
  ],
  caption: "Navigation Position Error — 3σ bounds from simulation"
)

#table(
  columns: (auto, auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Metric*], [*Mean*], [*3σ*], [*Requirement*],
  [Position error (m)],  [[AUTO]], [[AUTO]], [[MANUAL]],
  [Velocity error (m/s)],[AUTO]],  [[AUTO]], [[MANUAL]],
  [Attitude error (deg)],[[AUTO]], [[AUTO]], [[MANUAL]],
)

#pagebreak()

// ── 4. ATTITUDE CONTROL ALGORITHMS ──────────────────────────

= Attitude Control Algorithms

== Mode: Detumble

=== Algorithm Description

B-dot control law for initial detumble following separation or anomaly recovery:

$ bold(tau)_"cmd" = -k_"bdot" dot dot(bold(B))_"body" $

where $bold(B)_"body"$ is the measured magnetic field vector in body frame and
$k_"bdot"$ is the detumble gain.

=== Parameters

// [AUTO: extract from FSW config in .stella bundle]

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Parameter*], [*Value*], [*Units*],
  [$k_"bdot"$], [[AUTO]], [N·m·s/T²],
  [Exit condition: $|bold(omega)|$], [[AUTO]], [rad/s],
)

=== Simulation Results

// [AUTO: extract detumble phase from mode_id, compute angular rate convergence time]

#figure(
  rect(width: 100%, height: 2.5in, stroke: 1pt)[
    #align(center + horizon)[_[AUTO: angular rate vs. time during detumble phase]_]
  ],
  caption: "Angular Rate Convergence During Detumble"
)

== Mode: Nadir Pointing

=== Algorithm Description

PD attitude controller with nadir-pointing reference quaternion:

$ bold(tau)_"cmd" = -K_p bold(q)_"err,vec" - K_d bold(omega)_"err" $

where $bold(q)_"err"$ is the error quaternion between current and desired attitude,
and $bold(omega)_"err"$ is the angular rate error.

=== Parameters

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Parameter*], [*Value*], [*Units*],
  [$K_p$], [[AUTO]], [N·m/rad],
  [$K_d$], [[AUTO]], [N·m·s/rad],
  [Pointing accuracy (3σ)], [[AUTO]], [deg],
)

== Mode: Slew to Track

// [AUTO: populate from SlewToTrack phase in telemetry]

== Mode: Threat Tracking

=== Detection Logic

// [AUTO: describe OPIR sensor model from scenario config]

Threat detection is performed by checking whether the threat position vector,
transformed into sensor frame, falls within the sensor field of view:

$ "detect" = cases(
  "true"  & "if" angle(hat(bold(r))_"threat"^"sensor", hat(bold(z))_"boresight") lt.eq theta_"FOV" \
           & "AND" "SNR" gt "SNR"_"threshold",
  "false" & "otherwise"
) $

where $theta_"FOV" = $ [AUTO]° is the sensor half-angle.

=== Track Filter

// [MANUAL: describe track filter used for fire-control quality track generation]

=== Tracking Performance

// [AUTO: compute track error statistics from threat_position_truth vs. estimated channels]

#table(
  columns: (auto, auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Metric*], [*Mean*], [*3σ*], [*Requirement*],
  [Track position error (m)],    [[AUTO]], [[AUTO]], [[MANUAL]],
  [Track velocity error (m/s)],  [[AUTO]], [[AUTO]], [[MANUAL]],
  [Time to weapons quality (s)], [[AUTO]], [—],      [[MANUAL]],
)

#figure(
  rect(width: 100%, height: 2.5in, stroke: 1pt)[
    #align(center + horizon)[_[AUTO: tracking error vs. time with weapons-quality threshold line]_]
  ],
  caption: "Threat Track Error — Time to Fire-Control Quality"
)

#pagebreak()

// ── 5. GUIDANCE ALGORITHMS (INTERCEPTOR) ────────────────────

= Guidance Algorithms

== Proportional Navigation

=== Algorithm Description

Pure proportional navigation guidance law:

$ bold(a)_"cmd" = N' dot bold(V)_c dot bold(Omega)_"LOS" $

where $N'$ is the effective navigation ratio, $bold(V)_c$ is the closing velocity,
and $bold(Omega)_"LOS"$ is the LOS rotation rate vector.

=== Flight Phase Parameters

// [AUTO: extract gain schedule from FSW config in .stella bundle]

#table(
  columns: (auto, auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Phase*], [*Duration*], [*N'*], [*Notes*],
  [Boost],      [[AUTO] s], [[AUTO]], [],
  [Midcourse],  [[AUTO] s], [[AUTO]], [],
  [Terminal],   [[AUTO] s], [[AUTO]], [],
)

=== Engagement Performance

// [AUTO: populate miss distance, impact time, BDA from telemetry]

#table(
  columns: (auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Metric*], [*Value*],
  [INT-1 miss distance],    [[AUTO] m — [AUTO: HIT/MISS]],
  [INT-1 terminal phase duration], [[AUTO] s],
  [BDA delay],              [[AUTO] s],
  [INT-2 miss distance],    [[AUTO] m — [AUTO: HIT/MISS]],
  [Total engagement duration], [[AUTO] s],
)

#pagebreak()

// ── 6. MODE TRANSITION TIMELINE ─────────────────────────────

= Mission Timeline and Mode Transitions

// [AUTO: generate from mode_id column in telemetry, annotate with event markers]

#figure(
  rect(width: 100%, height: 3in, stroke: 1pt)[
    #align(center + horizon)[_[AUTO: swimlane timeline — each vehicle as a row, mode phases colored by state]_]
  ],
  caption: "GNC Mode Transition Timeline — All Vehicles"
)

#table(
  columns: (auto, auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*T (s)*], [*Vehicle*], [*Mode Transition*], [*Notes*],
  [[AUTO]], [[AUTO]], [[AUTO]], [],
  // Agent: enumerate all mode transitions from telemetry
)

#pagebreak()

// ── 7. ERROR BUDGET AND SENSITIVITY ─────────────────────────

= Error Budget and Sensitivity Analysis

== Navigation Error Contributions

// [AUTO: if Monte Carlo data available in bundle, compute CEP, 3σ bounds]
// [MANUAL: if single-run, note that Monte Carlo analysis is pending]

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Error Source*], [*1σ Contribution*], [*Notes*],
  [Star tracker noise],      [[AUTO]], [],
  [GPS measurement noise],   [[AUTO]], [],
  [IMU gyro noise],          [[AUTO]], [],
  [IMU accel noise],         [[AUTO]], [],
  [Gravity model error],     [[MANUAL]], [EGM2008 assumed],
  [Atmospheric drag (LEO)],  [[MANUAL]], [],
  [*RSS Total*],             [*[AUTO]*], [],
)

== Injected Fault Analysis

// [AUTO: detect any injected errors from scenario config, characterize their effect on performance]

#table(
  columns: (auto, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Fault*], [*Magnitude*], [*Observed Effect*],
  [[AUTO: e.g., "Nav bias — INT-1"]], [[AUTO]], [[AUTO]],
)

#pagebreak()

// ── 8. VERIFICATION AND VALIDATION ──────────────────────────

= Verification and Validation

== Simulation Configuration

// [AUTO: extract from .stella bundle metadata]

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt,
  [*Parameter*], [*Value*],
  [STELLA version],         [[AUTO]],
  [Physics rate],           [[AUTO] Hz],
  [FSW rate],               [[AUTO] Hz],
  [Simulation duration],    [[AUTO] s],
  [Number of vehicles],     [[AUTO]],
  [Scenario epoch],         [[AUTO]],
  [Bundle ID],              [[AUTO]],
  [Checksum],               [[AUTO]],
)

== Test Cases

#table(
  columns: (auto, 1fr, auto, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*ID*], [*Description*], [*Expected*], [*Result*],
  [TC-01], [Detumble convergence within time limit],    [[AUTO] s],     [[AUTO: PASS/FAIL]],
  [TC-02], [Nadir pointing accuracy],                   [[AUTO] deg],   [[AUTO: PASS/FAIL]],
  [TC-03], [Threat detection latency],                  [[AUTO] s],     [[AUTO: PASS/FAIL]],
  [TC-04], [Fire-control quality track acquisition],    [[AUTO] s],     [[AUTO: PASS/FAIL]],
  [TC-05], [Custody handoff continuity],                [No gap],       [[AUTO: PASS/FAIL]],
  [TC-06], [INT-2 intercept (post-BDA)],                [Miss < [AUTO] m], [[AUTO: PASS/FAIL]],
)

#pagebreak()

// ── 9. KNOWN LIMITATIONS ────────────────────────────────────

= Known Limitations and Open Items

// [MANUAL + AUTO: agent can flag any channels with anomalous values or missing data]

#table(
  columns: (auto, 1fr, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*ID*], [*Description*], [*Status*],
  [LIM-01], [Single-run simulation — Monte Carlo analysis pending], [Open],
  [LIM-02], [Spherical Earth model — WGS84 ellipsoid not yet implemented], [Open],
  [LIM-03], [Atmospheric drag model: exponential atmosphere, not NRLMSISE-00], [Open],
  [[AUTO]], [[AUTO: flag any NaN, overflow, or anomaly detected in telemetry]], [Open],
)

#pagebreak()

// ── 10. REFERENCES ──────────────────────────────────────────

= References

// [MANUAL + AUTO: agent should cite any models referenced in scenario config]

+ Vallado, D.A., _Fundamentals of Astrodynamics and Applications_, 4th ed., Microcosm Press, 2013.
+ Montenbruck, O. and Gill, E., _Satellite Orbits_, Springer, 2000.
+ Wertz, J.R., _Spacecraft Attitude Determination and Control_, Kluwer, 1978.
+ EGM2008: Pavlis, N.K. et al., "The development and evaluation of the Earth Gravitational Model 2008," _JGR Solid Earth_, 2012.
+ [MANUAL: program-specific ICDs, SDA interface documents]

// ── APPENDIX ────────────────────────────────────────────────

#pagebreak()

= Appendix A: Telemetry Channel Definitions

// [AUTO: generate from .stella bundle schema — list all channels used in this document]

#table(
  columns: (auto, auto, 1fr, auto),
  inset: 6pt,
  stroke: 0.5pt,
  fill: (col, row) => if row == 0 { luma(220) } else { white },
  [*Channel*], [*Units*], [*Description*], [*Source*],
  [[AUTO]], [[AUTO]], [[AUTO]], [STELLA telemetry],
)

= Appendix B: Full Telemetry Plots

// [AUTO: render all key telemetry channels as time-series plots]
// Suggested channels:
//   - position_eci_{x,y,z}
//   - velocity_eci_{x,y,z}
//   - attitude_quat_{w,x,y,z}
//   - angular_rate_{x,y,z}
//   - nav_error_pos_norm
//   - mode_id (step plot)
//   - threat_in_fov (binary)
//   - track_error_norm
//   - interceptor_miss_distance

