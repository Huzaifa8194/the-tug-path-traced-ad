"""Host for the path tracer: accumulates samples on the GPU, grades on the CPU, writes PNG stills or pipes frames to ffmpeg.

  python pt.py shot1 --t 0.3 --w 640 --h 360 --spp 32 --png out.png
  python pt.py shot1 --from 0 --to 2.6 --fps 24 --w 1280 --h 720 --spp 48 --mp4 shot1.mp4
  python pt.py shot5+office --t 2.0 --png corridor.png      (shot files are concatenated after common.glsl)
"""
import argparse, os, struct, subprocess, sys, time, zlib
import numpy as np
import moderngl
from scipy.ndimage import gaussian_filter

HERE = os.path.dirname(os.path.abspath(__file__))


def write_png(path, rgb):
    h, w, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def aces(x):
    return np.clip((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0, 1)


def grade(hdr, exposure, frame_index):
    """Lens and film: despeckle, bloom, slight chromatic aberration, vignette, filmic curve, grain."""
    h, w, _ = hdr.shape
    img = hdr * exposure
    # despeckle: a pixel may not be far brighter than the brightest of its blurred neighbourhood
    lum = img.mean(axis=2)
    soft = gaussian_filter(lum, 1.2)
    k = np.minimum(1.0, (soft * 3.0 + 0.05) / np.maximum(lum, 1e-6))
    img = img * k[..., None]
    # bloom from the bright parts
    bright = np.maximum(img - 1.0, 0)
    bloom = sum(gaussian_filter(bright, (s, s, 0)) for s in (w / 320, w / 110, w / 40)) / 3.0
    img = img + 0.55 * bloom
    # chromatic aberration: red slightly larger, blue slightly smaller
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = (w - 1) / 2, (h - 1) / 2
    def scaled(ch, s):
        xs = np.clip(cx + (xx - cx) * s, 0, w - 1).astype(np.int32)
        ys = np.clip(cy + (yy - cy) * s, 0, h - 1).astype(np.int32)
        return ch[ys, xs]
    img = np.dstack([scaled(img[..., 0], 0.9985), img[..., 1], scaled(img[..., 2], 1.0015)])
    r2 = ((xx - cx) / cx) ** 2 + ((yy - cy) / cx) ** 2
    img = img * (1.0 - 0.28 * np.clip(r2, 0, 1.6))[..., None]
    out = aces(img) ** (1 / 2.2)
    rng = np.random.default_rng(1000 + frame_index)
    g = gaussian_filter(rng.normal(0, 1, (h, w)), 0.6) * 0.022
    out = out + g[..., None] * (1.0 - 0.6 * out)
    return (np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)


class Tracer:
    def __init__(self, shot, w, h):
        self.w, self.h = w, h
        self.ctx = moderngl.create_standalone_context()
        src = open(os.path.join(HERE, "common.glsl")).read() + "".join("\n" + open(os.path.join(HERE, f + ".glsl")).read() for f in shot.split("+"))
        self.prog = self.ctx.program(vertex_shader="#version 330\nin vec2 p; void main(){ gl_Position = vec4(p,0,1); }", fragment_shader=src)
        self.vao = self.ctx.vertex_array(self.prog, [(self.ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], "f4").tobytes()), "2f", "p")])
        self.tex = self.ctx.texture((w, h), 4, dtype="f4")
        self.fbo = self.ctx.framebuffer([self.tex])
        self.prog["uRes"].value = (w, h)

    def frame(self, t, shutter, spp, seed0, tile=4):
        self.fbo.use(); self.fbo.clear(0, 0, 0, 0)
        self.ctx.enable(moderngl.BLEND); self.ctx.blend_func = moderngl.ONE, moderngl.ONE
        self.prog["uTime"].value = t
        if "uShutter" in self.prog: self.prog["uShutter"].value = shutter
        th = -(-self.h // tile)
        for s in range(spp):
            self.prog["uSeed"].value = seed0 * 7919 + s
            for i in range(tile):                      # small draws keep each GPU job short
                self.ctx.scissor = (0, i * th, self.w, min(th, self.h - i * th))
                self.vao.render(moderngl.TRIANGLES)
                self.ctx.finish()
        self.ctx.scissor = None
        a = np.frombuffer(self.fbo.read(components=4, dtype="f4"), "f4").reshape(self.h, self.w, 4)
        if a[..., 3].min() < spp - 0.5:
            raise RuntimeError("incomplete frame: min samples %.1f of %d" % (a[..., 3].min(), spp))
        return a[::-1, :, :3] / spp


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shot"); ap.add_argument("--w", type=int, default=640); ap.add_argument("--h", type=int, default=360)
    ap.add_argument("--spp", type=int, default=16); ap.add_argument("--t", type=float); ap.add_argument("--png")
    ap.add_argument("--from", dest="t0", type=float, default=0.0); ap.add_argument("--to", dest="t1", type=float)
    ap.add_argument("--fps", type=float, default=24.0); ap.add_argument("--mp4"); ap.add_argument("--exposure", type=float, default=1.0)
    ap.add_argument("--tile", type=int, default=4)
    a = ap.parse_args()
    tr = Tracer(a.shot, a.w, a.h)
    shutter = 0.5 / a.fps                              # 180 degree shutter
    if a.t is not None:
        t0 = time.time(); hdr = tr.frame(a.t, shutter, a.spp, int(a.t * 1000), a.tile)
        write_png(a.png or (a.shot + ".png"), grade(hdr, a.exposure, 0))
        print("still t=%.2f %dx%d %d spp in %.1fs  mean %.3f" % (a.t, a.w, a.h, a.spp, time.time() - t0, hdr.mean()))
        return
    n = int(round((a.t1 - a.t0) * a.fps))
    ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (a.w, a.h), "-r", str(a.fps),
                           "-i", "-", "-c:v", "libx264", "-crf", "14", "-preset", "medium", "-pix_fmt", "yuv420p", a.mp4], stdin=subprocess.PIPE)
    t0 = time.time()
    for i in range(n):
        t = a.t0 + i / a.fps
        for attempt in range(3):
            try:
                hdr = tr.frame(t, shutter, a.spp, i + 1, a.tile); break
            except RuntimeError as e:
                print("retry frame", i, e, flush=True)
        ff.stdin.write(grade(hdr, a.exposure, i).tobytes())
        if i % 6 == 0:
            el = time.time() - t0
            print("frame %d/%d  %.1fs/frame  eta %.0f min" % (i + 1, n, el / (i + 1), el / (i + 1) * (n - i - 1) / 60), flush=True)
    ff.stdin.close(); ff.wait()
    print("done %d frames in %.1f min -> %s" % (n, (time.time() - t0) / 60, a.mp4))


if __name__ == "__main__":
    main()
