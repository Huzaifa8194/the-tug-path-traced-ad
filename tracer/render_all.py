"""Renders every shot with the settings used for the released film, then the soundtrack, then the edit.
On the laptop this was made on (Intel UHD integrated graphics) the seven shots take about 3.5 hours in total.

  python render_all.py            everything
  python render_all.py --preview  quarter resolution, 8 samples: minutes instead of hours, noisy
"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(HERE, "out"), exist_ok=True)
preview = "--preview" in sys.argv

# shot, first second, last second, width, height, samples per pixel, exposure
SHOTS = [("shot1", 0.0, 2.8, 1280, 720, 160, 1.3),          # brass padlock on the bazaar shutter
         ("shot2", 0.0, 2.4, 1280, 720, 160, 1.3),          # disc lock on the house gate
         ("shot3", 0.25, 2.4, 1280, 720, 144, 1.3),         # safe dial and lever
         ("shot4", 0.0, 2.0, 1280, 720, 80, 1.3),           # chain and padlock in the rain
         ("shot5+office", 0.3, 3.8, 960, 540, 80, 1.6),     # corridor, server-room door ajar
         ("shot6+office", 0.5, 4.1, 960, 540, 80, 1.6),     # the door swings open
         ("shot7", 0.3, 4.3, 1280, 720, 96, 1.3)]           # lever handle, keypad turns red, red tag

for shot, t0, t1, w, h, spp, exposure in SHOTS:
    if preview: w, h, spp = w // 4, h // 4, 8
    out = os.path.join("out", shot.split("+")[0] + ".mp4")
    subprocess.check_call([sys.executable, "pt.py", shot, "--from", str(t0), "--to", str(t1), "--fps", "24", "--w", str(w), "--h", str(h),
                           "--spp", str(spp), "--exposure", str(exposure), "--mp4", out], cwd=HERE)
subprocess.check_call([sys.executable, "audio.py", os.path.join("out", "film.wav")], cwd=HERE)
subprocess.check_call([sys.executable, "assemble.py"], cwd=HERE)
