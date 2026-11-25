// Shot 4: a chain and padlock on a factory gate in heavy rain. A guard's torch from the left, a red tail-light low right.

const int NL = 11;
float pulse(float t, float t0) { float a = (t - t0) / 0.04; return exp(-a * a); }
float ring(float t, float t0) { float u = t - t0; return u < 0.0 ? 0.0 : exp(-u * 7.0) * sin(u * 70.0); }

vec3 linkPos(int i, float t, out float ang) {
  float u = float(i) / float(NL - 1);                 // 0..1 along the chain
  float x = mix(-0.115, 0.115, u);
  float sag = 0.060 * (1.0 - pow(abs(2.0 * u - 1.0), 2.0));
  float lag = 0.018 * abs(float(i) - 5.0);
  float rat = 0.007 * (ring(t, 0.22 + lag) + 1.15 * ring(t, 0.55 + lag)) + 0.006 * (pulse(t, 0.22) + pulse(t, 0.55)) * (1.0 - abs(2.0 * u - 1.0));
  ang = atan(-0.060 * 2.0 * (2.0 * u - 1.0) * 2.0, 0.23) + 0.5 * rat * 30.0 * (fract(float(i) * 0.37) - 0.5);
  return vec3(x, 0.045 - sag - rat, 0.040 + 0.004 * ring(t, 0.24 + lag));
}
float sdLink(vec3 p, float le, float r1, float r2) { vec3 q = vec3(p.x, max(abs(p.y) - le, 0.0), p.z); return length(vec2(length(q.xy) - r1, q.z)) - r2; }

float rain(vec3 p, float t) {
  const float C = 0.07, H = 0.6;
  vec2 cell = floor(p.xz / C); vec2 f = p.xz - (cell + 0.5) * C;
  float h1 = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453), h2 = fract(sin(dot(cell, vec2(269.5, 183.3))) * 43758.5453);
  vec2 o = (vec2(h1, h2) - 0.5) * C * 0.6;
  float y = mod(p.y + (6.5 + 2.0 * h2) * t + h1 * H, H) - 0.5 * H;
  float drop = length(vec3(f.x - o.x, y * 0.5, f.y - o.y)) - 0.0010;
  float edge = 0.5 * C - max(abs(f.x), abs(f.y)) + 0.003;          // never step past the cell without re-evaluating
  return min(drop, max(edge, 0.003));
}

vec2 map(vec3 p) {
  // two gate leaves meeting, square tube frames and a mesh of thin bars behind
  vec2 d = vec2(sdBox(p - vec3(-0.060, 0.0, 0.0), vec3(0.024, 3.0, 0.024), 0.004), 1.0);
  d = opU(d, vec2(sdBox(p - vec3(0.060, 0.0, 0.0), vec3(0.024, 3.0, 0.024), 0.004), 1.0));
  float xr = mod(p.x + 0.045, 0.09) - 0.045;
  d = opU(d, vec2(max(length(vec2(xr, p.z + 0.012)) - 0.006, 0.090 - abs(p.x)), 1.0));
  d = opU(d, vec2(sdBox(p - vec3(0.0, 0.16, -0.012), vec3(3.0, 0.018, 0.010), 0.003), 1.0));
  // chain
  float ch = 1e9;
  for (int i = 0; i < NL; i++) {
    float ang; vec3 c = linkPos(i, gT, ang);
    vec3 q = p - c; q.xy = rot(-(ang + PI * 0.5)) * q.xy;      // local y along the chain
    if (i % 2 == 1) q.xz = q.zx;
    ch = min(ch, sdLink(q, 0.0072, 0.0082, 0.0030));
  }
  d = opU(d, vec2(ch, 2.0));
  // small brass padlock through the middle link
  float ang; vec3 c5 = linkPos(5, gT, ang);
  vec3 q = p - c5 - vec3(0.0, -0.012, 0.004); q.xy = rot(0.25 * ring(gT, 0.3) + 0.3 * ring(gT, 0.62)) * q.xy;
  vec3 c = q - vec3(0.0, -0.010, 0.0);
  float shk = c.y > 0.0 ? sdTorusXY(c, 0.010, 0.0030) : min(sdCapsule(c, vec3(-0.010, 0, 0), vec3(-0.010, -0.016, 0), 0.0030), sdCapsule(c, vec3(0.010, 0, 0), vec3(0.010, -0.016, 0), 0.0030));
  d = opU(d, vec2(shk, 2.0));
  d = opU(d, vec2(sdBox(q - vec3(0.0, -0.038, 0.0), vec3(0.017, 0.0135, 0.0065), 0.0025), 3.0));
  // rain
  d = opU(d, vec2(rain(p, gT), 4.0));
  d = opU(d, vec2(p.y + 1.2, 5.0));
  return d;
}

void material(float id, vec3 p, inout Mat m) {
  if (id < 1.5) {                                    // wet blue-grey gate paint with rust blooms
    float n = fbm(p * 45.0), n2 = fbm(p * 240.0 + 3.0);
    float worn = smoothstep(0.58, 0.66, n + 0.1 * n2);
    m.base = mix(vec3(0.055, 0.085, 0.115), mix(vec3(0.06, 0.025, 0.012), vec3(0.17, 0.07, 0.03), n2), worn);
    float beads = smoothstep(0.62, 0.7, fbm(p * vec3(330.0, 150.0, 330.0) + vec3(0.0, gT * 4.0, 0.0)));
    m.rough = mix(0.10, 0.45, worn) * (1.0 - 0.6 * beads) + 0.03; m.metal = 0.0;
    m.nbump = vec3(fbm(p * 330.0 + vec3(0.4, gT * 4.0, 0)) - 0.5, fbm(p * 330.0 + vec3(0, gT * 4.0 + 0.4, 9.0)) - 0.5, 0.0) * 0.18 * beads;
  } else if (id < 2.5) {                             // galvanised chain, wet
    float n = fbm(p * 420.0);
    m.base = mix(vec3(0.62, 0.63, 0.66), vec3(0.24, 0.11, 0.05), smoothstep(0.6, 0.72, fbm(p * 150.0))); m.metal = 1.0 - smoothstep(0.6, 0.72, fbm(p * 150.0));
    m.rough = 0.13 + 0.2 * n; m.nbump = vec3(n - 0.5, fbm(p * 420.0 + 5.0) - 0.5, 0.0) * 0.15;
  } else if (id < 3.5) {                             // brass, wet
    float n = fbm(p * 200.0);
    m.base = mix(vec3(0.96, 0.72, 0.30), vec3(0.62, 0.42, 0.16), smoothstep(0.45, 0.7, n)); m.metal = 1.0; m.rough = 0.14 + 0.15 * n;
  } else if (id < 4.5) {                             // rain: bright against the torch
    m.base = vec3(0.9, 0.95, 1.0); m.rough = 0.3; m.metal = 0.0; m.emit = vec3(0.012, 0.014, 0.018);
  } else {
    float n = fbm(p * 2.5); m.base = vec3(0.03); m.rough = mix(0.04, 0.5, smoothstep(0.4, 0.62, n));
  }
}

int numLights() { return 3; }
void light(int i, out vec3 pos, out float rad, out vec3 col) {
  float jump = 0.02 * (ring(gT, 0.22) + ring(gT, 0.55));
  if (i == 0) { pos = vec3(-0.34, -0.10 + jump, 0.52); rad = 0.028; col = vec3(0.92, 0.96, 1.0) * 520.0; }    // torch
  else if (i == 1) { pos = vec3(0.75, -0.45, 0.55); rad = 0.07; col = vec3(1.0, 0.05, 0.03) * 70.0; }        // tail-light
  else { pos = vec3(0.3, 1.2, 0.8); rad = 0.3; col = vec3(0.3, 0.42, 0.75) * 1.6; }
}
int numBokeh() { return 14; }
void bokeh(int i, out vec3 pos, out float rad, out vec3 col) {
  float f = float(i);
  float a = fract(sin(f * 12.9898) * 43758.5453), b = fract(sin(f * 78.233) * 12345.678), c = fract(sin(f * 39.425) * 9876.543);
  pos = vec3(-3.0 + 6.0 * a, -0.6 + 2.2 * b * b, -4.0 - 9.0 * c); rad = 0.06 + 0.06 * c;
  col = (i % 3 == 0 ? vec3(1.0, 0.07, 0.04) : (i % 3 == 1 ? vec3(1.0, 0.55, 0.2) : vec3(0.8, 0.9, 1.0))) * (0.5 + 1.3 * b);
}
vec3 sky(vec3 rd) {
  float street = smoothstep(-0.2, 0.9, rd.z) * (0.5 + 0.5 * sin(rd.x * 7.0 + 2.0) * sin(rd.y * 5.0));
  return vec3(0.006, 0.008, 0.014) + vec3(0.8, 0.85, 1.0) * 0.06 * street + vec3(1.0, 0.1, 0.05) * 0.05 * smoothstep(0.3, 1.0, rd.x) * smoothstep(0.2, -0.6, rd.y);
}
float tMax() { return 30.0; }
void camera(out vec3 ro, out vec3 ta, out float fovY, out float focus, out float aperture) {
  ro = vec3(0.075, -0.115, 0.330);
  ta = vec3(-0.005, 0.005, 0.030);
  fovY = radians(31.0);
  focus = length(vec3(0.0, -0.015, 0.042) - ro);
  aperture = 0.008;
}
