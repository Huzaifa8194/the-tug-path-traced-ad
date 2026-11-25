"""Cuts the rendered shots into the film: trims, scales to 1920x1080, three title lines, the end card, the soundtrack."""
import os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
os.chdir(OUT)
# drawtext needs a font file next to the frames; set FONT to any bold .ttf on systems without Segoe UI
shutil.copy(os.environ.get("FONT", r"C:\Windows\Fonts\segoeuib.ttf"), "font.ttf")
shutil.copy(os.path.join(HERE, "..", "assets", "logo.png"), "logo.png")

# (file, seconds used)
CUTS = [("shot1.mp4", 2.6), ("shot2.mp4", 2.3), ("shot3.mp4", 2.0), ("shot4.mp4", 1.8), ("shot5.mp4", 3.5), ("shot6.mp4", 3.6), ("shot7.mp4", 4.0)]
END = 4.6
total = sum(d for _, d in CUTS)

def line(name, text):
    open(name, "w", encoding="utf-8").write(text)
line("t1.txt", "Everyone checks the lock"); line("t2.txt", "Who checks everything else?"); line("t3.txt", "We do")
line("e1.txt", "Everyone checks the lock."); line("e2.txt", "We check everything else."); line("e3.txt", "Talk to our team"); line("e4.txt", "info@digiinn360.com")

def title(txt, t0, t1, size=92, y="h-250", x=150):
    a = "if(lt(t,%f),0,if(lt(t,%f),(t-%f)/0.25,if(lt(t,%f),1,if(lt(t,%f),(%f-t)/0.25,0))))" % (t0, t0 + 0.25, t0, t1 - 0.25, t1, t1)
    return "drawtext=fontfile=font.ttf:textfile=%s:fontsize=%d:fontcolor=white:x=%d:y=%s:alpha='%s':shadowcolor=black@0.55:shadowx=0:shadowy=3" % (txt, size, x, y, a)

def fadein(t0, d=0.35):
    return "if(lt(t,%f),0,if(lt(t,%f),(t-%f)/%f,1))" % (t0, t0 + d, t0, d)

inputs, fc, labels = [], [], []
for i, (f, d) in enumerate(CUTS):
    inputs += ["-i", f]
    fc.append("[%d:v]trim=0:%f,setpts=PTS-STARTPTS,fps=24,scale=1920:1080:flags=lanczos,unsharp=5:5:0.35,setsar=1[v%d]" % (i, d, i))
    labels.append("[v%d]" % i)
n = len(CUTS)
fc.append("".join(labels) + "concat=n=%d:v=1:a=0[film0]" % n)
fc.append("[film0]" + ",".join([title("t1.txt", 9.5, 11.9), title("t2.txt", 13.7, 15.6), title("t3.txt", 17.6, 19.55, 120, "h-300", 800),
                               "fade=t=out:st=%f:d=0.35:c=white" % (total - 0.35)]) + "[film]")
# end card: white ground, the real logo, the line, a red button, the address
inputs += ["-f", "lavfi", "-i", "color=c=white:s=1920x1080:r=24:d=%f" % END, "-loop", "1", "-t", str(END), "-i", "logo.png"]
fc.append("[%d:v]scale=820:-1,format=rgba,fade=t=in:st=0.15:d=0.45:alpha=1[lg]" % (n + 1))
card = ["[%d:v][lg]overlay=x=(W-w)/2:y=120:shortest=1" % n,
        "drawtext=fontfile=font.ttf:textfile=e1.txt:fontsize=66:fontcolor=0x06183A:x=(w-text_w)/2:y=560:alpha='%s'" % fadein(0.7),
        "drawtext=fontfile=font.ttf:textfile=e2.txt:fontsize=66:fontcolor=0xDB000A:x=(w-text_w)/2:y=645:alpha='%s'" % fadein(1.15),
        "drawbox=x=760:y=790:w=400:h=92:color=0xDB000A@1:t=fill:enable='gte(t,1.7)'",
        "drawtext=fontfile=font.ttf:textfile=e3.txt:fontsize=42:fontcolor=white:x=(w-text_w)/2:y=812:enable='gte(t,1.7)'",
        "drawtext=fontfile=font.ttf:textfile=e4.txt:fontsize=38:fontcolor=0x06183A:x=(w-text_w)/2:y=925:alpha='%s'" % fadein(1.95)]
fc.append(",".join(card) + ",format=yuv420p[card]")
fc.append("[film]format=yuv420p[filmy];[filmy][card]concat=n=2:v=1:a=0[v]")
inputs += ["-i", "film.wav"]
cmd = ["ffmpeg", "-v", "error", "-y"] + inputs + ["-filter_complex", ";".join(fc), "-map", "[v]", "-map", "%d:a" % (n + 2),
       "-c:v", "libx264", "-crf", "20", "-preset", "slow", "-pix_fmt", "yuv420p", "-af", "volume=5.5dB,alimiter=limit=0.75:attack=1:release=60:level=disabled", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart",
       "-t", str(total + END), os.path.join(HERE, "..", "the-tug.mp4")]
r = subprocess.run(cmd)
print("total %.1f s, exit %d" % (total + END, r.returncode))
