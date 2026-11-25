// Shot 1: a brass padlock on a painted steel shutter, old bazaar lane, night, sodium lamp.
// The lock is tugged twice, then released to swing. Units are metres.

const vec3 PIVOT = vec3(0.0, 0.052, 0.019);   // where the shackle hangs in the staple
const float SR = 0.016;                        // shackle arc radius

float jerk(float t) { float a = (t - 0.22) / 0.04, b = (t - 0.58) / 0.04; return 0.0055 * exp(-a * a) + 0.0065 * exp(-b * b); }
float shiver(float t) {
  float s = 0.0;
  if (t > 0.22) s += exp(-(t - 0.22) * 8.0) * sin((t - 0.22) * 88.0);
  if (t > 0.58) s += 1.2 * exp(-(t - 0.58) * 8.0) * sin((t - 0.58) * 88.0);
  return 0.0011 * s;
}
float swing(float t) { float u = t - 0.86; return u < 0.0 ? 0.035 * sin(t * 9.0) : 0.035 * sin(0.86 * 9.0) + 0.20 * exp(-1.25 * u) * sin(u * 14.0); }
float tilt(float t) { float u = t - 0.86; return u < 0.0 ? 0.0 : 0.07 * exp(-2.0 * u) * sin(u * 19.0 + 0.8); }
float handOut(float t) { return smoothstep(0.80, 1.25, t); }

vec3 lockLocal(vec3 p) {
  vec3 q = p - PIVOT; q.z -= shiver(gT);
  q.y += jerk(gT);
  q.xy = rot(-swing(gT)) * q.xy;
  q.yz = rot(-tilt(gT)) * q.yz;
  return q;
}
float slat(float y) { float s = abs(sin(PI * y / 0.046)); return 0.0085 * pow(s * s + 0.004, 0.32); }

vec2 map(vec3 p) {
  vec3 w = p; w.z -= shiver(gT);
  // roller shutter: horizontal convex slats, ends at x = 0.058
  float sh = max((w.z - slat(w.y + 0.01)) * 0.5, w.x - 0.050);
  sh = max(sh, -(w.z + 0.03));
  vec2 d = vec2(sh, 1.0);
  // side guide channel and hasp plate
  d = opU(d, vec2(sdBox(w - vec3(0.062, 0.0, 0.006), vec3(0.012, 2.0, 0.020), 0.003), 2.0));
  d = opU(d, vec2(sdBox(w - vec3(0.0, 0.070, 0.0135), vec3(0.020, 0.024, 0.003), 0.002), 2.0));
  // staple: a steel ring standing out of the hasp plate
  d = opU(d, vec2(sdTorusYZ(w - vec3(0.0, 0.0535, 0.0165), 0.0135, 0.0036), 3.0));
  // padlock
  vec3 q = lockLocal(p);
  vec3 c = q - vec3(0.0, -SR, 0.0);
  float shk = c.y > 0.0 ? sdTorusXY(c, SR, 0.0046) : min(sdCapsule(c, vec3(-SR, 0, 0), vec3(-SR, -0.03, 0), 0.0046), sdCapsule(c, vec3(SR, 0, 0), vec3(SR, -0.03, 0), 0.0046));
  d = opU(d, vec2(shk, 4.0));
  vec3 bq = q - vec3(0.0, -SR - 0.040, 0.0);
  float body = sdBox(bq, vec3(0.0245, 0.0195, 0.0088), 0.0032);
  body = max(body, -sdCylZ(bq - vec3(0.0, -0.007, 0.0092), 0.0034, 0.0015));       // keyway recess
  d = opU(d, vec2(body, 5.0));
  // the person who tugs is never seen: only an arm between the lamp and the lock, out of frame, casting a soft shadow
  float ho = handOut(gT);
  vec3 hc = vec3(-0.150, 0.168, 0.186) + vec3(0.0, -jerk(gT) * 2.0, 0.0) + ho * vec3(0.30, 0.06, 0.12);
  float arm = smin(sdCapsule(p, hc + vec3(-0.035, 0.03, 0.0), hc + vec3(0.30, 0.12, 0.26), 0.036),
                   sdCapsule(p, hc + vec3(-0.035, 0.03, 0.0), hc + vec3(-0.075, -0.005, -0.03), 0.030), 0.02);
  d = opU(d, vec2(arm, 6.0));
  // lane floor
  d = opU(d, vec2(p.y + 1.15, 7.0));
  return d;
}

void material(float id, vec3 p, inout Mat m) {
  vec3 w = p; w.z -= shiver(gT);
  if (id < 2.5) {                                    // painted steel (shutter, channel, hasp)
    float chips = fbm(w * vec3(55.0, 38.0, 55.0));
    float chips2 = fbm(w * vec3(140.0, 110.0, 140.0) + 7.0);
    float groove = 1.0 - smoothstep(0.002, 0.006, slat(w.y + 0.01));
    float worn = smoothstep(0.585, 0.635, chips + 0.07 * groove * step(id, 1.5) + 0.12 * chips2);
    float streak = fbm(vec3(w.x * 260.0, w.y * 9.0, 1.0));
    vec3 paint = mix(vec3(0.060, 0.215, 0.140), vec3(0.105, 0.285, 0.195), streak) * (0.75 + 0.5 * chips2);
    vec3 rust = mix(vec3(0.11, 0.040, 0.018), vec3(0.27, 0.115, 0.045), chips2) * (0.6 + 0.8 * fbm(w * 700.0));
    m.base = mix(paint, rust, worn);
    m.rough = mix(0.42 + 0.2 * streak, 0.9, worn);
    m.metal = 0.0;
    float e = fbm(w * 420.0) - 0.5; m.nbump = vec3(e, fbm(w * 420.0 + 31.0) - 0.5, 0.0) * mix(0.05, 0.35, worn);
  } else if (id < 3.5) {                             // staple: old steel, rust in the bends
    float r = fbm(w * 300.0);
    m.base = mix(vec3(0.42, 0.42, 0.43), vec3(0.28, 0.12, 0.05), smoothstep(0.45, 0.62, r));
    m.metal = 1.0 - smoothstep(0.45, 0.62, r); m.rough = mix(0.34, 0.85, smoothstep(0.45, 0.62, r));
  } else if (id < 4.5) {                             // shackle: hardened steel, fine scuffs
    vec3 q = lockLocal(p);
    float s = fbm(q * vec3(900.0, 120.0, 900.0));
    m.base = vec3(0.66, 0.67, 0.69) * (0.8 + 0.3 * s); m.metal = 1.0; m.rough = 0.18 + 0.22 * s;
  } else if (id < 5.5) {                             // brass body: brushed, tarnished, dented
    vec3 q = lockLocal(p);
    float brush = fbm(vec3(q.x * 90.0, q.y * 1500.0, q.z * 90.0));
    float tarn = fbm(q * 85.0 + 3.0);
    float pit = smoothstep(0.66, 0.74, fbm(q * 520.0));
    m.base = mix(vec3(0.98, 0.74, 0.30), vec3(0.66, 0.44, 0.17), smoothstep(0.50, 0.78, tarn)) * (1.0 - 0.5 * pit);
    m.metal = 1.0;
    m.rough = clamp(0.17 + 0.16 * brush + 0.18 * smoothstep(0.50, 0.78, tarn) + 0.3 * pit, 0.14, 0.9);
    m.nbump = vec3(0.0, brush - 0.5, 0.0) * 0.06 + vec3(fbm(q * 260.0) - 0.5, fbm(q * 260.0 + 9.0) - 0.5, 0.0) * 0.07;
  } else if (id < 6.5) {                             // skin, out of focus
    m.base = vec3(0.36, 0.215, 0.14); m.rough = 0.62; m.metal = 0.0;
  } else {                                           // wet lane
    float n = fbm(p * 2.2);
    m.base = vec3(0.035, 0.035, 0.038); m.rough = mix(0.05, 0.55, smoothstep(0.42, 0.62, n)); m.metal = 0.0;
  }
}

int numLights() { return 2; }
void light(int i, out vec3 pos, out float rad, out vec3 col) {
  if (i == 0) { pos = vec3(-0.55, 0.62, 0.62); rad = 0.055; col = vec3(1.0, 0.56, 0.20) * 300.0; }   // sodium lamp, upper left
  else { pos = vec3(1.4, 0.35, 0.9); rad = 0.20; col = vec3(0.30, 0.42, 0.75) * 2.2; }               // cool spill from the lane
}
int numBokeh() { return 22; }
void bokeh(int i, out vec3 pos, out float rad, out vec3 col) {
  float f = float(i);
  float a = fract(sin(f * 12.9898) * 43758.5453), b = fract(sin(f * 78.233) * 12345.678), c = fract(sin(f * 39.425) * 9876.543);
  pos = vec3(0.7 + 4.6 * a, -0.6 + 2.0 * b * b, -3.0 - 10.0 * c);
  rad = 0.05 + 0.06 * fract(a * 7.0);
  vec3 warm = vec3(1.0, 0.55, 0.18), white = vec3(0.9, 0.95, 1.0), red = vec3(1.0, 0.06, 0.04);
  col = (i % 5 == 0 ? red : (i % 3 == 0 ? white : warm)) * (0.7 + 1.8 * b);
}
vec3 sky(vec3 rd) {
  // what the metal reflects: the lit lane behind the camera, a warm wash around the lamp, a cool night above
  vec3 L0 = normalize(vec3(-0.55, 0.62, 0.62));
  float lamp = pow(max(dot(rd, L0), 0.0), 3.0);
  float street = smoothstep(-0.2, 0.9, rd.z) * (0.55 + 0.45 * sin(rd.x * 9.0 + 1.3) * sin(rd.y * 7.0));
  return vec3(0.004, 0.006, 0.012) * (0.6 + 0.4 * rd.y) + vec3(1.0, 0.58, 0.25) * (0.34 * lamp + 0.075 * street) + vec3(0.25, 0.4, 0.8) * 0.02 * smoothstep(0.2, 1.0, rd.x);
}
float tMax() { return 30.0; }
void camera(out vec3 ro, out vec3 ta, out float fovY, out float focus, out float aperture) {
  ro = vec3(-0.115, 0.004, 0.285);
  ta = vec3(0.030, 0.000, 0.012);
  fovY = radians(22.0);
  focus = length(vec3(0.0, 0.0, 0.021) - ro) * 0.985;
  aperture = 0.012;
}
