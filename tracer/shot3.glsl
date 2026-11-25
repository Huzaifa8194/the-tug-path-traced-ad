// Shot 3: an old steel safe. The dial is spun shut, then the lever handle is pulled twice. One tungsten desk lamp.

const vec2 DIAL = vec2(-0.085, 0.022);
const vec2 HUB = vec2(0.075, -0.012);

float pulse(float t, float t0) { float a = (t - t0) / 0.045; return exp(-a * a); }
float lever(float t) { return -0.10 - 0.24 * (pulse(t, 0.78) + 1.1 * pulse(t, 1.12)); }           // angle below horizontal
float spin(float t) { float u = clamp(t / 0.55, 0.0, 1.0); return 4.2 * (1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u)); }
float shiver(float t) {
  float s = 0.0;
  if (t > 0.78) s += exp(-(t - 0.78) * 14.0) * sin((t - 0.78) * 150.0);
  if (t > 1.12) s += 1.2 * exp(-(t - 1.12) * 14.0) * sin((t - 1.12) * 150.0);
  return 0.00035 * s;
}

vec2 map(vec3 p) {
  vec3 w = p; w.z -= shiver(gT);
  // door slab with a seam on the right, and the body beyond it
  float door = sdBox(w - vec3(-0.25, 0.0, -0.03), vec3(0.445, 1.0, 0.03), 0.004);
  float bodyR = sdBox(w - vec3(0.45, 0.0, -0.036), vec3(0.25, 1.0, 0.03), 0.004);
  vec2 d = vec2(min(door, bodyR), 1.0);
  // dial: ring plate, knurled wheel, centre knob
  vec3 q = w - vec3(DIAL, 0.0);
  d = opU(d, vec2(sdCylZ(q - vec3(0, 0, 0.0025), 0.058, 0.0025) - 0.0008, 2.0));
  d = opU(d, vec2(sdCylZ(q - vec3(0, 0, 0.012), 0.044, 0.008) - 0.002, 3.0));
  d = opU(d, vec2(sdCylZ(q - vec3(0, 0, 0.026), 0.017, 0.008) - 0.003, 4.0));
  // handle: boss, hub and lever with a ball end
  vec3 h = w - vec3(HUB, 0.0);
  d = opU(d, vec2(sdCylZ(h - vec3(0, 0, 0.004), 0.030, 0.004) - 0.001, 5.0));
  d = opU(d, vec2(sdCylZ(h - vec3(0, 0, 0.022), 0.0165, 0.018) - 0.002, 5.0));
  float a = lever(gT); vec3 dir = vec3(cos(a), sin(a), 0.0);
  d = opU(d, vec2(sdCapsule(h, vec3(0, 0, 0.034), vec3(0, 0, 0.034) + dir * 0.115, 0.0082), 5.0));
  d = opU(d, vec2(length(h - vec3(0, 0, 0.034) - dir * 0.125) - 0.0145, 5.0));
  // hinge barrel at the far left, rivets along the top
  d = opU(d, vec2(sdCapsule(w, vec3(-0.40, -0.05, 0.004), vec3(-0.40, 0.09, 0.004), 0.011), 5.0));
  vec3 rv = w - vec3(0.0, 0.118, 0.0); rv.x = mod(rv.x + 0.035, 0.07) - 0.035;
  d = opU(d, vec2(length(rv * vec3(1, 1, 1.6)) - 0.0065, 1.0));
  return d;
}

void material(float id, vec3 p, inout Mat m) {
  vec3 w = p; w.z -= shiver(gT);
  if (id < 1.5) {                                    // hammered enamel, deep grey-green, worn at the edges
    float ham = fbm(w * 95.0), n = fbm(w * 30.0 + 2.0), n2 = fbm(w * 300.0);
    float worn = smoothstep(0.70, 0.76, n + 0.1 * n2);
    m.base = mix(mix(vec3(0.050, 0.075, 0.070), vec3(0.085, 0.115, 0.105), ham), vec3(0.16, 0.15, 0.14), worn);
    m.rough = mix(0.30, 0.6, worn) + 0.15 * n2; m.metal = worn * 0.8;
    m.nbump = vec3(fbm(w * 95.0 + vec3(0.6, 0, 0)) - ham, fbm(w * 95.0 + vec3(0, 0.6, 0)) - ham, 0.0) * 0.7;
  } else if (id < 2.5) {                             // black dial ring with white index ticks
    vec2 q = w.xy - DIAL; float ang = atan(q.y, q.x), r = length(q);
    float tick = smoothstep(0.42, 0.5, abs(fract(ang / (2.0 * PI) * 50.0) - 0.5)) * step(0.047, r) * step(r, 0.0555);
    m.base = mix(vec3(0.015), vec3(0.85, 0.83, 0.76), 1.0 - tick > 0.5 ? 0.0 : 1.0); m.rough = 0.35;
  } else if (id < 3.5) {                             // brass wheel: knurled rim, engraved numbers ring
    vec2 q = w.xy - DIAL; float ang = atan(q.y, q.x) + spin(gT), r = length(q);
    float knurl = sin(ang * 90.0) * step(0.040, r);
    float mark = smoothstep(0.40, 0.5, abs(fract(ang / (2.0 * PI) * 20.0) - 0.5)) * step(0.030, r) * step(r, 0.039);
    float tarn = fbm(vec3(q * 60.0, 1.0) + vec3(cos(spin(gT)), sin(spin(gT)), 0.0) * 0.0);
    m.base = mix(vec3(0.95, 0.70, 0.28), vec3(0.60, 0.40, 0.15), smoothstep(0.45, 0.75, tarn)); m.base = mix(m.base, vec3(0.03), mark);
    m.metal = 1.0 - mark; m.rough = 0.20 + 0.2 * tarn + 0.3 * mark;
    m.nbump = vec3(-sin(ang), cos(ang), 0.0) * knurl * 0.45;
  } else if (id < 4.5) {                             // knob: polished brass
    m.base = vec3(0.97, 0.74, 0.30); m.metal = 1.0; m.rough = 0.13 + 0.12 * fbm(w * 400.0);
  } else {                                           // chromed steel handle, fine wear
    float s = fbm(w * vec3(500.0, 500.0, 500.0)), pit = smoothstep(0.7, 0.78, fbm(w * 900.0));
    m.base = vec3(0.72, 0.73, 0.75) * (1.0 - 0.5 * pit); m.metal = 1.0; m.rough = clamp(0.12 + 0.14 * s + 0.4 * pit, 0.12, 0.8);
  }
}

int numLights() { return 2; }
void light(int i, out vec3 pos, out float rad, out vec3 col) {
  if (i == 0) { pos = vec3(-0.46, 0.30, 0.42); rad = 0.05; col = vec3(1.0, 0.66, 0.34) * 95.0; }          // desk lamp, left
  else { pos = vec3(0.9, -0.3, 0.9); rad = 0.3; col = vec3(0.35, 0.45, 0.75) * 0.5; }                     // faint window fill
}
int numBokeh() { return 0; }
void bokeh(int i, out vec3 pos, out float rad, out vec3 col) { pos = vec3(0); rad = 0.0; col = vec3(0); }
vec3 sky(vec3 rd) {
  // the dark shop the metal reflects: lamp glow on the left, a few gold glints low on the right
  vec3 L0 = normalize(vec3(-0.46, 0.30, 0.42));
  float lamp = pow(max(dot(rd, L0), 0.0), 2.5);
  float gold = pow(max(0.0, sin(rd.x * 23.0) * sin(rd.y * 31.0 + 1.0)), 6.0) * smoothstep(0.1, 0.8, rd.x) * smoothstep(0.3, -0.5, rd.y);
  return vec3(0.004, 0.004, 0.006) + vec3(1.0, 0.62, 0.3) * (0.22 * lamp + 0.5 * gold);
}
float tMax() { return 8.0; }
void camera(out vec3 ro, out vec3 ta, out float fovY, out float focus, out float aperture) {
  ro = vec3(0.165, -0.090, 0.455);
  ta = vec3(0.022, -0.006, 0.010);
  fovY = radians(27.0);
  focus = length(vec3(HUB, 0.03) - ro);
  aperture = 0.010;
}
