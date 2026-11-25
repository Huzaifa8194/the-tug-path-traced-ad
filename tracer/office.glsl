// Shots 5 and 6: an office corridor at night. At its end a server-room door stands a finger's width open (shot 5,
// slow push-in), then swings open by itself (shot 6). SHOT is defined by the file placed before this one. Metres.

float doorAngle(float t) {
#if SHOT == 5
  return 0.17 + 0.006 * sin(t * 1.7);
#else
  float u = clamp((t - 0.9) / 2.3, 0.0, 1.0); u = u * u * (3.0 - 2.0 * u);
  return 0.17 + 1.15 * u;
#endif
}
float flick(float t) { float k = floor(t * 17.0); float h = fract(sin(k * 91.7) * 4375.85); return h > 0.80 ? 0.5 : (h > 0.68 ? 0.8 : 1.0); }

vec3 doorLocal(vec3 p) { vec3 q = p - vec3(0.90, 0.0, -0.035); q.xz = rot(doorAngle(gT)) * q.xz; return q; }   // hinge on the right

vec2 map(vec3 p) {
  // corridor shell
  vec2 d = vec2(p.y, 1.0);                                                        // carpet
  d = opU(d, vec2(2.60 - p.y, 2.0));                                              // ceiling
  d = opU(d, vec2(p.x + 1.30, 3.0));                                              // left wall
  d = opU(d, vec2(1.15 - p.x, 3.0));                                              // right wall
  float endWall = sdBox(p - vec3(0.0, 1.3, -0.06), vec3(1.6, 1.4, 0.06), 0.0);
  endWall = max(endWall, -sdBox(p - vec3(0.45, 1.02, -0.06), vec3(0.45, 1.03, 0.2), 0.0));
  d = opU(d, vec2(endWall, 3.0));
  // door frame
  float fr = min(sdBox(p - vec3(-0.035, 1.03, -0.045), vec3(0.035, 1.06, 0.055), 0.004), sdBox(p - vec3(0.935, 1.03, -0.045), vec3(0.035, 1.06, 0.055), 0.004));
  fr = min(fr, sdBox(p - vec3(0.45, 2.09, -0.045), vec3(0.52, 0.035, 0.055), 0.004));
  d = opU(d, vec2(fr, 4.0));
  // door slab and lever handles
  vec3 q = doorLocal(p);
  d = opU(d, vec2(sdBox(q - vec3(-0.445, 1.025, 0.0), vec3(0.443, 1.02, 0.022), 0.003), 5.0));
  vec3 h = q - vec3(-0.815, 1.02, 0.0);
  float hd = min(sdCapsule(h, vec3(0, 0, -0.07), vec3(0, 0, 0.07), 0.011), sdCapsule(h, vec3(0, 0, 0.062), vec3(0.125, 0, 0.062), 0.010));
  hd = min(hd, sdCylZ(h - vec3(0, 0, 0.025), 0.027, 0.004));
  d = opU(d, vec2(hd, 6.0));
  // keypad on the wall left of the frame, skirting, a fire extinguisher, ceiling light panels
  d = opU(d, vec2(sdBox(p - vec3(-0.20, 1.18, 0.012), vec3(0.038, 0.062, 0.012), 0.004), 7.0));
  d = opU(d, vec2(min(sdBox(p - vec3(-1.29, 0.05, 2.0), vec3(0.012, 0.05, 4.0), 0.002), sdBox(p - vec3(1.14, 0.05, 2.0), vec3(0.012, 0.05, 4.0), 0.002)), 4.0));
  d = opU(d, vec2(sdBox(p - vec3(-0.1, 2.595, 1.15), vec3(0.30, 0.01, 0.60), 0.0), 9.0));
  d = opU(d, vec2(sdBox(p - vec3(-0.1, 2.595, 4.60), vec3(0.30, 0.01, 0.60), 0.0), 10.0));
  // server room behind the wall: floor is shared, back wall, two racks
  d = opU(d, vec2(p.z + 3.2, 11.0));
  d = opU(d, vec2(sdBox(p - vec3(0.10, 1.0, -2.3), vec3(0.30, 1.0, 0.45), 0.01), 12.0));
  d = opU(d, vec2(sdBox(p - vec3(0.80, 1.0, -2.3), vec3(0.30, 1.0, 0.45), 0.01), 12.0));
  return d;
}

void material(float id, vec3 p, inout Mat m) {
  if (id < 1.5) {                                    // carpet tiles
    vec2 t = fract(p.xz / 0.5); float seam = smoothstep(0.012, 0.0, min(min(t.x, 1.0 - t.x), min(t.y, 1.0 - t.y)) * 0.5);
    float f = fbm(p * vec3(160.0, 1.0, 160.0)), g = fbm(p * vec3(9.0, 1.0, 9.0));
    m.base = vec3(0.070, 0.075, 0.085) * (0.6 + 0.8 * f) * (0.85 + 0.3 * g) * (1.0 - 0.4 * seam); m.rough = 0.95;
    m.nbump = vec3(f - 0.5, 0.0, fbm(p * 160.0 + 7.0) - 0.5) * 0.5;
  } else if (id < 2.5) {                             // ceiling tiles
    vec2 t = fract(p.xz / 0.6); float seam = smoothstep(0.02, 0.0, min(min(t.x, 1.0 - t.x), min(t.y, 1.0 - t.y)));
    m.base = vec3(0.55, 0.56, 0.57) * (1.0 - 0.6 * seam) * (0.9 + 0.2 * fbm(p * 60.0)); m.rough = 0.9;
  } else if (id < 3.5) {                             // painted walls, scuffed low down
    float n = fbm(p * 40.0), scuff = smoothstep(0.62, 0.7, fbm(p * vec3(6.0, 20.0, 6.0))) * smoothstep(1.1, 0.2, p.y);
    m.base = vec3(0.50, 0.52, 0.54) * (0.92 + 0.16 * n) * (1.0 - 0.35 * scuff); m.rough = 0.62 + 0.2 * n;
    m.nbump = vec3(fbm(p * 300.0) - 0.5, fbm(p * 300.0 + 3.0) - 0.5, 0.0) * 0.06;
  } else if (id < 4.5) {                             // frame and skirting: dark grey satin
    m.base = vec3(0.045, 0.047, 0.052); m.rough = 0.38 + 0.1 * fbm(p * 80.0);
  } else if (id < 5.5) {                             // door: matte grey laminate with a faint orange-peel
    vec3 q = doorLocal(p);
    m.base = vec3(0.235, 0.245, 0.26) * (0.94 + 0.12 * fbm(q * vec3(3.0, 40.0, 3.0))); m.rough = 0.48;
    m.nbump = vec3(fbm(q * 260.0) - 0.5, fbm(q * 260.0 + 5.0) - 0.5, 0.0) * 0.05;
  } else if (id < 6.5) {                             // satin steel handle
    m.base = vec3(0.70, 0.71, 0.73); m.metal = 1.0; m.rough = 0.24 + 0.1 * fbm(p * 500.0);
  } else if (id < 7.5) {                             // keypad with one green light
    vec2 k = (p.xy - vec2(-0.20, 1.18)); m.base = vec3(0.02); m.rough = 0.4;
    vec2 g = fract((k + vec2(0.03, 0.045)) / vec2(0.02, 0.0225)); float btn = step(0.2, g.x) * step(g.x, 0.8) * step(0.2, g.y) * step(g.y, 0.8) * step(k.y, 0.03);
    m.base += vec3(0.05) * btn;
    if (length(k - vec2(0.0, 0.048)) < 0.0055) m.emit = vec3(0.1, 1.0, 0.25) * 6.0;
  } else if (id < 8.5) {
    m.base = vec3(0.55, 0.03, 0.02); m.rough = 0.25;
  } else if (id < 9.5) {                             // the tube that flickers, nearest the door
    m.emit = vec3(0.80, 0.90, 1.0) * 3.2 * flick(gT); m.base = vec3(0.0);
  } else if (id < 10.5) {
    m.emit = vec3(0.80, 0.90, 1.0) * 1.2; m.base = vec3(0.0);
  } else if (id < 11.5) {
    m.base = vec3(0.10, 0.11, 0.12); m.rough = 0.7;
  } else {                                           // racks: black mesh fronts with rows of status lights
    m.base = vec3(0.012); m.rough = 0.45;
    vec2 u = vec2(p.x * 64.0, p.y * 30.0); vec2 c = floor(u), f = fract(u);
    float h = fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
    float on = step(0.80, h) * step(0.35, fract(h * 13.0 + gT * (0.7 + 3.0 * h)));
    if (p.z > -1.87 && length(f - 0.5) < 0.11) m.emit = (fract(h * 7.0) > 0.25 ? vec3(0.1, 1.0, 0.3) : vec3(1.0, 0.55, 0.05)) * 9.0 * on;
  }
}

int numLights() { return 3; }
void light(int i, out vec3 pos, out float rad, out vec3 col) {
  if (i == 0) { pos = vec3(-0.1, 2.42, 1.15); rad = 0.11; col = vec3(0.80, 0.90, 1.0) * 26.0 * flick(gT); }      // flickering tube
  else if (i == 1) { pos = vec3(-0.1, 2.42, 4.60); rad = 0.11; col = vec3(0.80, 0.90, 1.0) * 9.0; }              // far tube
  else { pos = vec3(-0.75, 1.35, -1.15); rad = 0.14; col = vec3(0.20, 1.0, 0.42) * 34.0; }                        // glow of the racks
}
int numBokeh() { return 0; }
void bokeh(int i, out vec3 pos, out float rad, out vec3 col) { pos = vec3(0); rad = 0.0; col = vec3(0); }
vec3 sky(vec3 rd) { return vec3(0.002); }
float tMax() { return 14.0; }
void camera(out vec3 ro, out vec3 ta, out float fovY, out float focus, out float aperture) {
#if SHOT == 5
  float u = clamp(gT / 4.0, 0.0, 1.0);
  ro = vec3(-0.50 + 0.12 * u, 1.38, 5.20 - 1.90 * u);
  ta = vec3(0.30, 1.10, 0.0);
  fovY = radians(44.0);
#else
  ro = vec3(-0.62, 1.28, 2.55);
  ta = vec3(0.34, 1.06, 0.0);
  fovY = radians(36.0);
#endif
  focus = length(vec3(0.05, 1.05, 0.0) - ro);
  aperture = 0.006;
}
