// Shot 7: the server-room door, now shut. The keypad light goes from green to red, the lever handle is tugged twice
// and holds, and a small red tag hung on it swings. The light warms as the door is made safe.

float pulse(float t, float t0) { float a = (t - t0) / 0.045; return exp(-a * a); }
float dip(float t) { return 0.20 * (pulse(t, 1.30) + 1.1 * pulse(t, 1.66)); }                 // lever pushed down, springs back
float shiver(float t) {
  float s = 0.0;
  if (t > 1.30) s += exp(-(t - 1.30) * 16.0) * sin((t - 1.30) * 170.0);
  if (t > 1.66) s += 1.2 * exp(-(t - 1.66) * 16.0) * sin((t - 1.66) * 170.0);
  return 0.00025 * s;
}
float tagSwing(float t) {
  float u = t - 1.30, v = t - 1.66;
  float a = 0.045 * sin(t * 5.2);
  if (u > 0.0) a += 0.30 * exp(-0.9 * u) * sin(u * 10.5);
  if (v > 0.0) a += 0.26 * exp(-0.9 * v) * sin(v * 10.5 + 0.6);
  return a;
}
float warm(float t) { return smoothstep(0.9, 2.6, t); }
float armOut(float t) { return smoothstep(1.95, 2.5, t) + (1.0 - smoothstep(0.75, 1.15, t)); }   // arm comes in, tugs, leaves
bool locked(float t) { return t > 0.62; }

vec3 leverLocal(vec3 p) { vec3 q = p; q.z -= shiver(gT); q.xy = rot(dip(gT)) * q.xy; return q; }     // pivot at the origin
vec3 tagLocal(vec3 p) {
  vec3 q = leverLocal(p) - vec3(-0.070, -0.0095, 0.052);          // hangs under the lever
  q.xy = rot(-dip(gT)) * q.xy;                                      // gravity keeps it vertical
  q.xy = rot(-tagSwing(gT)) * q.xy; q.yz = rot(-0.5 * tagSwing(gT + 0.13)) * q.yz;
  return q;
}

vec2 map(vec3 p) {
  vec3 w = p; w.z -= shiver(gT);
  vec2 d = vec2(w.z, 1.0);                                                         // door face
  d = opU(d, vec2(sdBox(w - vec3(0.245, 0.0, 0.004), vec3(0.028, 3.0, 0.018), 0.003), 2.0));        // frame on the right
  d = opU(d, vec2(sdCylZ(w - vec3(0, 0, 0.004), 0.027, 0.004) - 0.0012, 3.0));     // rosette
  vec3 q = leverLocal(p);
  float lv = min(sdCapsule(q, vec3(0, 0, 0.006), vec3(0, 0, 0.052), 0.0105), sdCapsule(q, vec3(0, 0, 0.052), vec3(-0.135, 0, 0.052), 0.0098));
  d = opU(d, vec2(lv, 3.0));
  // keypad on the frame side
  d = opU(d, vec2(sdBox(w - vec3(0.150, 0.045, 0.007), vec3(0.030, 0.050, 0.007), 0.003), 4.0));
  // tag: string loop and a paper card with a punched hole
  vec3 t = tagLocal(p);
  d = opU(d, vec2(sdTorusXY(t - vec3(0.0, -0.004, 0.0), 0.0135, 0.0006), 5.0));
  float card = sdBox(t - vec3(0.0, -0.047, 0.0), vec3(0.0155, 0.026, 0.00035), 0.0003);
  card = max(card, -(length(t.xy - vec2(0.0, -0.0255)) - 0.0022));
  d = opU(d, vec2(card, 6.0));
  // unseen arm between the cold light and the handle
  vec3 hc = vec3(-0.175, 0.085, 0.215) + vec3(0.0, -dip(gT) * 0.05, 0.0) + armOut(gT) * vec3(-0.25, 0.20, 0.10);
  d = opU(d, vec2(sdCapsule(p, hc + vec3(0.03, -0.02, 0.0), hc + vec3(-0.30, 0.12, 0.26), 0.036), 7.0));
  return d;
}

void material(float id, vec3 p, inout Mat m) {
  vec3 w = p; w.z -= shiver(gT);
  if (id < 1.5) {                                    // matte grey laminate, fingerprints near the handle
    float n = fbm(w * vec3(4.0, 60.0, 4.0)), smudge = smoothstep(0.55, 0.75, fbm(w * 45.0)) * smoothstep(0.16, 0.03, length(w.xy - vec2(-0.05, 0.0)));
    m.base = vec3(0.225, 0.235, 0.25) * (0.94 + 0.12 * n); m.rough = 0.50 - 0.22 * smudge;
    m.nbump = vec3(fbm(w * 380.0) - 0.5, fbm(w * 380.0 + 5.0) - 0.5, 0.0) * 0.07;
  } else if (id < 2.5) {
    m.base = vec3(0.04, 0.042, 0.047); m.rough = 0.36 + 0.1 * fbm(w * 90.0);
  } else if (id < 3.5) {                             // satin stainless lever, brushed along its length
    vec3 q = leverLocal(p);
    float br = fbm(vec3(q.x * 60.0, q.y * 1400.0, q.z * 1400.0)), wear = smoothstep(0.5, 0.8, fbm(q * 70.0));
    m.base = vec3(0.74, 0.75, 0.77) * (0.88 + 0.2 * br); m.metal = 1.0; m.rough = clamp(0.20 + 0.14 * br - 0.08 * wear, 0.13, 0.6);
    m.nbump = vec3(0.0, br - 0.5, 0.0) * 0.05;
  } else if (id < 4.5) {                             // keypad: rubber keys, one status light
    vec2 k = w.xy - vec2(0.150, 0.045);
    vec2 g = fract((k + vec2(0.024, 0.040)) / vec2(0.016, 0.0165));
    float btn = step(0.18, g.x) * step(g.x, 0.82) * step(0.18, g.y) * step(g.y, 0.82) * step(k.y, 0.026) * step(-0.040, k.y) * step(abs(k.x), 0.024);
    m.base = mix(vec3(0.018), vec3(0.075, 0.078, 0.085), btn); m.rough = mix(0.35, 0.6, btn);
    m.nbump = vec3(g - 0.5, 0.0) * 0.25 * btn;
    if (length(k - vec2(0.0, 0.038)) < 0.0042) m.emit = (locked(gT) ? vec3(1.0, 0.06, 0.04) : vec3(0.1, 1.0, 0.25)) * 9.0;
  } else if (id < 5.5) {                             // waxed string
    m.base = vec3(0.75, 0.72, 0.64); m.rough = 0.8;
  } else if (id < 6.5) {                             // red card, paper fibre
    vec3 t = tagLocal(p); float f = fbm(t * vec3(700.0, 300.0, 700.0));
    m.base = vec3(0.72, 0.035, 0.04) * (0.85 + 0.3 * f); m.rough = 0.72;
    m.nbump = vec3(f - 0.5, fbm(t * 700.0 + 4.0) - 0.5, 0.0) * 0.12;
  } else {
    m.base = vec3(0.10, 0.10, 0.11); m.rough = 0.7;
  }
}

int numLights() { return 3; }
void light(int i, out vec3 pos, out float rad, out vec3 col) {
  float k = warm(gT);
  if (i == 0) { pos = vec3(-0.50, 0.42, 0.62); rad = 0.07; col = vec3(0.72, 0.86, 1.0) * 150.0 * (1.0 - 0.65 * k); }     // cold ceiling tube
  else if (i == 1) { pos = vec3(0.55, 0.10, 0.60); rad = 0.06; col = vec3(1.0, 0.66, 0.34) * 115.0 * k; }               // warm desk lamp comes up
  else { pos = vec3(0.0, -0.8, 0.9); rad = 0.3; col = vec3(0.4, 0.5, 0.7) * 0.9; }
}
int numBokeh() { return 0; }
void bokeh(int i, out vec3 pos, out float rad, out vec3 col) { pos = vec3(0); rad = 0.0; col = vec3(0); }
vec3 sky(vec3 rd) {
  // the corridor the steel reflects: a cold strip overhead, a warm pool to the right once the lamp is on
  float k = warm(gT);
  float tube = smoothstep(0.75, 0.95, rd.y) + pow(max(dot(rd, normalize(vec3(-0.5, 0.42, 0.62))), 0.0), 3.0);
  float lamp = pow(max(dot(rd, normalize(vec3(0.55, 0.10, 0.60))), 0.0), 3.0);
  return vec3(0.006, 0.007, 0.010) + vec3(0.72, 0.86, 1.0) * 0.16 * tube * (1.0 - 0.6 * k) + vec3(1.0, 0.66, 0.34) * 0.30 * lamp * k;
}
float tMax() { return 8.0; }
void camera(out vec3 ro, out vec3 ta, out float fovY, out float focus, out float aperture) {
  float u = clamp(gT / 4.4, 0.0, 1.0);
  ro = vec3(-0.165 + 0.02 * u, -0.045, 0.345 - 0.03 * u);
  ta = vec3(0.012, -0.022, 0.020);
  fovY = radians(30.0);
  focus = length(vec3(-0.06, -0.02, 0.052) - ro);
  aperture = 0.008;
}
