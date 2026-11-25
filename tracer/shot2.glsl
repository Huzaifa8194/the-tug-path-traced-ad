// Shot 2: a steel disc padlock on a black wrought-iron house gate. Warm porch light behind, street light in front.

const vec3 PIVOT = vec3(0.0, 0.0, 0.020);
const float SR = 0.013;

float jerk(float t) { float a = (t - 0.25) / 0.04, b = (t - 0.60) / 0.04; return 0.0050 * exp(-a * a) + 0.0060 * exp(-b * b); }
float shiver(float t) {
  float s = 0.0;
  if (t > 0.25) s += exp(-(t - 0.25) * 11.0) * sin((t - 0.25) * 120.0);
  if (t > 0.60) s += 1.2 * exp(-(t - 0.60) * 11.0) * sin((t - 0.60) * 120.0);
  return 0.0006 * s;
}
float swing(float t) { float u = t - 0.86; return u < 0.0 ? -0.03 * sin(t * 8.0) : -0.03 * sin(0.86 * 8.0) - 0.17 * exp(-1.3 * u) * sin(u * 13.0); }
float tilt(float t) { float u = t - 0.86; return u < 0.0 ? 0.0 : 0.09 * exp(-1.8 * u) * sin(u * 17.0 + 0.5); }
float armOut(float t) { return smoothstep(0.80, 1.25, t); }

vec3 lockLocal(vec3 p) {
  vec3 q = p - PIVOT; q.z -= shiver(gT); q.y += jerk(gT);
  q.xy = rot(-swing(gT)) * q.xy; q.yz = rot(-tilt(gT)) * q.yz;
  return q;
}

vec2 map(vec3 p) {
  vec3 w = p; w.z -= shiver(gT);
  // gate: a flat rail, round pickets every 11 cm, a lower rail
  vec2 d = vec2(sdBox(w - vec3(0.0, 0.034, 0.0), vec3(3.0, 0.013, 0.0045), 0.0015), 1.0);
  d = opU(d, vec2(sdBox(w - vec3(0.0, -0.33, 0.0), vec3(3.0, 0.013, 0.0045), 0.0015), 1.0));
  float xr = mod(w.x + 0.062, 0.11) - 0.055;
  d = opU(d, vec2(length(vec2(xr, w.z + 0.008)) - 0.0075, 1.0));
  // sliding bolt and its two keepers
  d = opU(d, vec2(sdCapsule(w, vec3(-0.115, 0.034, 0.0135), vec3(0.070, 0.034, 0.0135), 0.0062), 2.0));
  d = opU(d, vec2(sdBox(w - vec3(-0.075, 0.034, 0.011), vec3(0.009, 0.012, 0.010), 0.002), 1.0));
  d = opU(d, vec2(sdBox(w - vec3(0.048, 0.034, 0.011), vec3(0.009, 0.012, 0.010), 0.002), 1.0));
  // welded ring the lock hangs from
  d = opU(d, vec2(sdTorusYZ(w - vec3(0.0, 0.0105, 0.0150), 0.0125, 0.0034), 2.0));
  // disc padlock
  vec3 q = lockLocal(p);
  vec3 c = q - vec3(0.0, -SR, 0.0);
  float shk = c.y > 0.0 ? sdTorusXY(c, SR, 0.0042) : min(sdCapsule(c, vec3(-SR, 0, 0), vec3(-SR, -0.022, 0), 0.0042), sdCapsule(c, vec3(SR, 0, 0), vec3(SR, -0.022, 0), 0.0042));
  d = opU(d, vec2(shk, 3.0));
  vec3 bq = q - vec3(0.0, -SR - 0.042, 0.0);
  float body = sdCylZ(bq, 0.0285, 0.0075) - 0.0035;
  body = max(body, -(sdCylZ(bq - vec3(0.0, 0.0, 0.0115), 0.0075, 0.002)));
  d = opU(d, vec2(body, 4.0));
  // unseen arm between the street lamp and the lock
  vec3 hc = vec3(0.150, 0.075, 0.185) + vec3(0.0, -jerk(gT) * 2.0, 0.0) + armOut(gT) * vec3(-0.30, 0.10, 0.10);
  d = opU(d, vec2(sdCapsule(p, hc + vec3(0.03, 0.02, 0.0), hc + vec3(-0.30, 0.16, 0.25), 0.036), 6.0));
  // courtyard floor behind the gate
  d = opU(d, vec2(p.y + 1.0, 7.0));
  return d;
}

void material(float id, vec3 p, inout Mat m) {
  vec3 w = p; w.z -= shiver(gT);
  if (id < 1.5) {                                    // black gate paint, chipped to rust on edges
    float n = fbm(w * vec3(70.0, 70.0, 70.0)), n2 = fbm(w * 260.0 + 4.0);
    float worn = smoothstep(0.60, 0.66, n + 0.12 * n2);
    m.base = mix(vec3(0.018, 0.018, 0.020), mix(vec3(0.10, 0.04, 0.018), vec3(0.26, 0.11, 0.045), n2), worn);
    m.rough = mix(0.22 + 0.2 * n2, 0.9, worn); m.metal = 0.0;
    m.nbump = vec3(fbm(w * 500.0) - 0.5, fbm(w * 500.0 + 17.0) - 0.5, 0.0) * mix(0.10, 0.35, worn);
  } else if (id < 2.5) {                             // bolt and ring: worn bright where hands and steel rub
    float n = fbm(w * vec3(40.0, 600.0, 600.0));
    m.base = mix(vec3(0.50, 0.50, 0.52), vec3(0.20, 0.09, 0.04), smoothstep(0.52, 0.7, fbm(w * 180.0)));
    m.metal = 1.0 - smoothstep(0.52, 0.7, fbm(w * 180.0)); m.rough = 0.22 + 0.3 * n;
  } else if (id < 3.5) {                             // shackle
    vec3 q = lockLocal(p); float s = fbm(q * vec3(900.0, 120.0, 900.0));
    m.base = vec3(0.68, 0.69, 0.71) * (0.8 + 0.3 * s); m.metal = 1.0; m.rough = 0.16 + 0.2 * s;
  } else if (id < 4.5) {                             // stainless disc, spun finish, scratches
    vec3 q = lockLocal(p) - vec3(0.0, -SR - 0.042, 0.0);
    float r = length(q.xy);
    float spun = fbm(vec3(r * 2600.0, atan(q.y, q.x) * 2.0, q.z * 60.0));
    float scr = smoothstep(0.70, 0.76, fbm(vec3(q.x * 900.0 + q.y * 300.0, q.y * 70.0, 2.0)));
    m.base = vec3(0.74, 0.75, 0.77) * (0.85 + 0.2 * spun) * (1.0 - 0.3 * scr); m.metal = 1.0;
    m.rough = clamp(0.17 + 0.18 * spun + 0.3 * scr, 0.13, 0.8);
    float groove = smoothstep(0.0006, 0.0, abs(r - 0.0215));
    m.nbump = normalize(vec3(q.xy, 0.0) + 1e-5) * (spun - 0.5) * 0.08 - vec3(0, 0, 0.25) * groove;
    m.base *= 1.0 - 0.5 * groove;
  } else if (id < 6.5) {
    m.base = vec3(0.30, 0.19, 0.13); m.rough = 0.65;
  } else {
    float n = fbm(p * 3.0);
    m.base = vec3(0.07, 0.065, 0.06); m.rough = mix(0.1, 0.7, smoothstep(0.4, 0.6, n));
  }
}

int numLights() { return 3; }
void light(int i, out vec3 pos, out float rad, out vec3 col) {
  if (i == 0) { pos = vec3(-0.50, 0.42, -0.55); rad = 0.07; col = vec3(1.0, 0.62, 0.30) * 150.0; }      // porch light behind: rims the lock
  else if (i == 1) { pos = vec3(0.62, 0.34, 0.74); rad = 0.06; col = vec3(1.0, 0.56, 0.20) * 130.0; }   // street lamp in front
  else { pos = vec3(-1.2, 0.6, 1.0); rad = 0.25; col = vec3(0.30, 0.42, 0.75) * 1.3; }                  // night fill
}
int numBokeh() { return 16; }
void bokeh(int i, out vec3 pos, out float rad, out vec3 col) {
  float f = float(i);
  float a = fract(sin(f * 12.9898) * 43758.5453), b = fract(sin(f * 78.233) * 12345.678), c = fract(sin(f * 39.425) * 9876.543);
  if (i < 6) { pos = vec3(-0.75 + 0.5 * a, 0.05 + 0.5 * b, -3.6); rad = 0.11; col = vec3(1.0, 0.66, 0.30) * (1.2 + 1.2 * c); }   // a lit kitchen window
  else { pos = vec3(-2.5 + 5.5 * a, -0.5 + 1.8 * b * b, -5.0 - 8.0 * c); rad = 0.05 + 0.05 * c; col = (i % 4 == 0 ? vec3(0.8, 0.9, 1.0) : vec3(1.0, 0.55, 0.2)) * (0.5 + 1.2 * b); }
}
vec3 sky(vec3 rd) {
  float street = smoothstep(-0.2, 0.9, rd.z) * (0.55 + 0.45 * sin(rd.x * 8.0 + 0.4) * sin(rd.y * 6.0 + 1.0));
  return vec3(0.004, 0.006, 0.013) * (0.6 + 0.4 * rd.y) + vec3(1.0, 0.58, 0.25) * 0.085 * street + vec3(1.0, 0.6, 0.3) * 0.05 * smoothstep(0.3, 1.0, -rd.z);
}
float tMax() { return 30.0; }
void camera(out vec3 ro, out vec3 ta, out float fovY, out float focus, out float aperture) {
  ro = vec3(0.105, -0.058, 0.270);
  ta = vec3(-0.012, -0.028, 0.012);
  fovY = radians(25.0);
  focus = length(vec3(0.0, -0.05, 0.026) - ro);
  aperture = 0.011;
}
