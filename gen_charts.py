#!/usr/bin/env python3
"""Generate ADD charts from evasion.stella bundle."""

import json
import numpy as np
import pyarrow.parquet as pq
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from pathlib import Path

plt.rcParams.update({
    "figure.facecolor": "white",
    "axes.facecolor": "white",
    "axes.grid": True,
    "grid.alpha": 0.3,
    "font.size": 10,
})

BUNDLE = Path("results/evasion.stella")
CHARTS = Path("results/charts")
CHARTS.mkdir(parents=True, exist_ok=True)

with open(BUNDLE / "scene.json") as f:
    scene = json.load(f)

f16_poses = pq.read_table(BUNDLE / "entities/f16/poses.parquet").to_pandas()
f16_sc = pq.read_table(BUNDLE / "entities/f16/scalars.parquet").to_pandas()
msl_poses = pq.read_table(BUNDLE / "entities/missile/poses.parquet").to_pandas()
msl_sc = pq.read_table(BUNDLE / "entities/missile/scalars.parquet").to_pandas()

f16_t = f16_sc["time"].values
msl_t = msl_sc["time"].values
f16_pos = f16_poses[["pos_x","pos_y","pos_z"]].values
msl_pos = msl_poses[["pos_x","pos_y","pos_z"]].values
pose_t = f16_poses["time"].values

n = min(len(f16_pos), len(msl_pos))
rng = np.linalg.norm(f16_pos[:n] - msl_pos[:n], axis=1)
rng_t = pose_t[:n]
min_idx = np.argmin(rng)

# ── Chart 1: Engagement Geometry ───────────────────────────
fig, ax = plt.subplots(figsize=(10, 7))
ax.plot(f16_pos[:,1], f16_pos[:,0], color="#0064ff", linewidth=2, label="F-16 Fighting Falcon")
ax.plot(msl_pos[:,1], msl_pos[:,0], color="#ff3200", linewidth=2, label="AIM-9 Sidewinder")
ax.scatter([f16_pos[0,1]], [f16_pos[0,0]], color="#0064ff", s=100, zorder=5, marker="o")
ax.scatter([msl_pos[0,1]], [msl_pos[0,0]], color="#ff3200", s=100, zorder=5, marker="^")
ax.scatter([f16_pos[min_idx,1]], [f16_pos[min_idx,0]], color="#0064ff", s=150, marker="*", zorder=6)
ax.scatter([msl_pos[min_idx,1]], [msl_pos[min_idx,0]], color="#ff3200", s=150, marker="*", zorder=6)
ax.plot([f16_pos[min_idx,1], msl_pos[min_idx,1]], [f16_pos[min_idx,0], msl_pos[min_idx,0]], "k--", linewidth=1, alpha=0.5)
ax.annotate(f"CPA: {rng[min_idx]:.0f} m\nt={rng_t[min_idx]:.1f}s",
    xy=((f16_pos[min_idx,1]+msl_pos[min_idx,1])/2, (f16_pos[min_idx,0]+msl_pos[min_idx,0])/2),
    fontsize=9, ha="center", bbox=dict(boxstyle="round,pad=0.3", facecolor="lightyellow", edgecolor="gray"))
for t_mark in [0, 5, 10, 15, 20, 25]:
    idx_f = np.argmin(np.abs(pose_t - t_mark))
    idx_m = np.argmin(np.abs(msl_poses["time"].values - t_mark))
    if idx_f < len(f16_pos):
        ax.annotate(f"{t_mark}s", (f16_pos[idx_f,1], f16_pos[idx_f,0]), fontsize=7, color="#0064ff")
    if idx_m < len(msl_pos):
        ax.annotate(f"{t_mark}s", (msl_pos[idx_m,1], msl_pos[idx_m,0]), fontsize=7, color="#ff3200")
ax.set_xlabel("East (m)")
ax.set_ylabel("North (m)")
ax.set_title("Engagement Geometry — Top-Down View (NED)")
ax.legend(loc="upper left")
ax.set_aspect("equal")
fig.savefig(str(CHARTS / "engagement_geometry.png"), dpi=150, bbox_inches="tight")
plt.close(fig)
print("  engagement_geometry.png")

# ── Chart 2: Range vs Time ─────────────────────────────────
fig, ax = plt.subplots(figsize=(10, 4))
ax.plot(rng_t, rng, color="#1e40af", linewidth=2)
ax.axvline(rng_t[min_idx], color="#ef4444", linewidth=1, linestyle="--", alpha=0.7, label=f"CPA: {rng[min_idx]:.0f} m at t={rng_t[min_idx]:.1f}s")
ax.axhline(rng[min_idx], color="#ef4444", linewidth=0.8, linestyle=":", alpha=0.5)
ax.set_xlabel("Time (s)")
ax.set_ylabel("Range (m)")
ax.set_title("F-16 to Missile Range")
ax.legend()
fig.savefig(str(CHARTS / "range_vs_time.png"), dpi=150, bbox_inches="tight")
plt.close(fig)
print("  range_vs_time.png")

# ── Chart 3: F-16 Flight Parameters ───────────────────────
fig, axes = plt.subplots(4, 1, figsize=(10, 10), sharex=True)
axes[0].plot(f16_t, f16_sc["f16_bank_angle_deg"], color="#0064ff", linewidth=1.5)
axes[0].set_ylabel("Bank Angle (°)")
axes[0].set_title("F-16 Flight Parameters During Evasion")
axes[0].axhline(80, color="gray", linestyle="--", linewidth=0.8, alpha=0.5, label="Target: 80°")
axes[0].legend(fontsize=8)
axes[1].plot(f16_t, f16_sc["f16_g_load"], color="#10b981", linewidth=1.5)
axes[1].axhline(9.0, color="#ef4444", linestyle="--", linewidth=0.8, label="Structural limit: 9G")
axes[1].set_ylabel("G-Load")
axes[1].legend(fontsize=8)
axes[2].plot(f16_t, f16_sc["f16_altitude_m"], color="#8b5cf6", linewidth=1.5)
axes[2].set_ylabel("Altitude (m)")
axes[3].plot(f16_t, f16_sc["f16_speed_mps"], color="#f59e0b", linewidth=1.5)
axes[3].set_ylabel("Speed (m/s)")
axes[3].set_xlabel("Time (s)")
for ax in axes:
    ax.axvspan(0.5, 12.5, alpha=0.08, color="red")
fig.tight_layout()
fig.savefig(str(CHARTS / "f16_flight_params.png"), dpi=150, bbox_inches="tight")
plt.close(fig)
print("  f16_flight_params.png")

# ── Chart 4: Missile Guidance Parameters ───────────────────
fig, axes = plt.subplots(4, 1, figsize=(10, 10), sharex=True)
axes[0].plot(msl_t, msl_sc["missile_speed_mps"], color="#ff3200", linewidth=1.5)
axes[0].set_ylabel("Speed (m/s)")
axes[0].set_title("AIM-9 Sidewinder Guidance Parameters")
axes[1].plot(msl_t, msl_sc["missile_closing_speed"], color="#1e40af", linewidth=1.5)
axes[1].axhline(0, color="gray", linewidth=0.5)
axes[1].set_ylabel("Closing Speed (m/s)")
axes[2].plot(msl_t, msl_sc["missile_lateral_accel_g"], color="#10b981", linewidth=1.5)
axes[2].axhline(30, color="#ef4444", linestyle="--", linewidth=0.8, label="Max: 30G")
axes[2].set_ylabel("Lateral Accel (G)")
axes[2].legend(fontsize=8)
axes[3].plot(msl_t, msl_sc["missile_fuel_kg"], color="#f59e0b", linewidth=1.5)
axes[3].set_ylabel("Fuel (kg)")
axes[3].set_xlabel("Time (s)")
for ax in axes:
    ax.axvspan(0, 5.8, alpha=0.08, color="orange")
fig.tight_layout()
fig.savefig(str(CHARTS / "missile_guidance_params.png"), dpi=150, bbox_inches="tight")
plt.close(fig)
print("  missile_guidance_params.png")

# ── Chart 5: Mode Timeline ────────────────────────────────
fig, ax = plt.subplots(figsize=(10, 2.5))
f16_phase = f16_sc["f16_phase"].values
pc = {0: ("#3b82f6","Cruise"), 1: ("#ef4444","Break Turn"), 2: ("#10b981","Extend")}
for pv, (color, name) in pc.items():
    mask = f16_phase == pv
    if np.any(mask):
        segs = np.diff(np.concatenate([[False], mask, [False]]).astype(int))
        for s, e in zip(np.where(segs==1)[0], np.where(segs==-1)[0]):
            ts = f16_t[min(s, len(f16_t)-1)]
            te = f16_t[min(e-1, len(f16_t)-1)]
            ax.barh(1, te-ts, left=ts, height=0.6, color=color, edgecolor="white", linewidth=0.5)

msl_phase = msl_sc["missile_phase"].values
mc = {0: ("#f59e0b","Boost"), 1: ("#dc2626","Terminal"), 2: ("#6b7280","Expended")}
for pv, (color, name) in mc.items():
    mask = msl_phase == pv
    if np.any(mask):
        segs = np.diff(np.concatenate([[False], mask, [False]]).astype(int))
        for s, e in zip(np.where(segs==1)[0], np.where(segs==-1)[0]):
            ts = msl_t[min(s, len(msl_t)-1)]
            te = msl_t[min(e-1, len(msl_t)-1)]
            ax.barh(0, te-ts, left=ts, height=0.6, color=color, edgecolor="white", linewidth=0.5)

for event in scene["events"]:
    ax.axvline(event["t"], color="black", linewidth=0.8, linestyle="--", alpha=0.5)
ax.set_yticks([0, 1])
ax.set_yticklabels(["AIM-9", "F-16"])
ax.set_xlabel("Time (s)")
ax.set_title("Mission Phase Timeline")
ax.set_xlim(0, 25)
patches = [mpatches.Patch(color=c, label=n) for c,n in [("#3b82f6","Cruise"),("#ef4444","Break Turn"),("#10b981","Extend"),("#f59e0b","Boost"),("#dc2626","Terminal"),("#6b7280","Expended")]]
ax.legend(handles=patches, loc="upper right", fontsize=8, ncol=3)
fig.tight_layout()
fig.savefig(str(CHARTS / "mode_timeline.png"), dpi=150, bbox_inches="tight")
plt.close(fig)
print("  mode_timeline.png")

# ── Summary ────────────────────────────────────────────────
print(f"\n=== Summary ===")
print(f"CPA: {rng[min_idx]:.1f} m at t={rng_t[min_idx]:.1f} s")
print(f"F-16 max bank: {np.max(np.abs(f16_sc['f16_bank_angle_deg'])):.1f}°")
print(f"F-16 max G: {np.max(f16_sc['f16_g_load']):.1f}")
print(f"F-16 speed: {np.min(f16_sc['f16_speed_mps']):.0f}–{np.max(f16_sc['f16_speed_mps']):.0f} m/s")
print(f"Missile max speed: {np.max(msl_sc['missile_speed_mps']):.0f} m/s")
print(f"Missile max lat G: {np.max(msl_sc['missile_lateral_accel_g']):.1f}")
