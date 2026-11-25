// Shared path-tracer core. A shot file is appended after this and must define:
//   vec2  map(vec3 p)                      signed distance and material id
//   void  material(float id, vec3 p, inout Mat m)
//   int   numLights(), void light(int i, out vec3 pos, out float rad, out vec3 col)   sampled sphere lights
//   int   numBokeh(),  void bokeh(int i, out vec3 pos, out float rad, out vec3 col)   distant unsampled emitters
//   vec3  sky(vec3 rd), float tMax()
//   void  camera(out vec3 ro, out vec3 ta, out float fovY, out float focus, out float aperture)
// gT is the time of the current sample (varies across the shutter for motion blur).
#version 330
uniform vec2 uRes;
uniform float uTime;
uniform float uShutter;
uniform int uSeed;
out vec4 fragColor;

float gT;
uint gS;
const float PI = 3.14159265;

uint pcg(uint v) { uint s = v * 747796405u + 2891336453u; uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u; return (w >> 22u) ^ w; }
float rnd() { gS = pcg(gS); return float(gS) / 4294967296.0; }
vec2 rnd2() { return vec2(rnd(), rnd()); }

float hash1(vec3 p) { p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419)); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
  vec3 i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(hash1(i), hash1(i + vec3(1, 0, 0)), f.x), mix(hash1(i + vec3(0, 1, 0)), hash1(i + vec3(1, 1, 0)), f.x), f.y),
             mix(mix(hash1(i + vec3(0, 0, 1)), hash1(i + vec3(1, 0, 1)), f.x), mix(hash1(i + vec3(0, 1, 1)), hash1(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.03 + 11.7; a *= 0.5; } return s; }

float sdBox(vec3 p, vec3 b, float r) { vec3 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r; }
float sdCapsule(vec3 p, vec3 a, vec3 b, float r) { vec3 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h) - r; }
float sdTorusXY(vec3 p, float R, float r) { return length(vec2(length(p.xy) - R, p.z)) - r; }
float sdTorusYZ(vec3 p, float R, float r) { return length(vec2(length(p.yz) - R, p.x)) - r; }
float sdCylZ(vec3 p, float r, float h) { vec2 d = vec2(length(p.xy) - r, abs(p.z) - h); return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)); }
float smin(float a, float b, float k) { float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k * h * (1.0 - h); }
mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }
vec2 opU(vec2 a, vec2 b) { return a.x < b.x ? a : b; }

struct Mat { vec3 base; float metal; float rough; vec3 emit; vec3 nbump; };

vec2 map(vec3 p);
void material(float id, vec3 p, inout Mat m);
void light(int i, out vec3 pos, out float rad, out vec3 col);
void bokeh(int i, out vec3 pos, out float rad, out vec3 col);
vec3 sky(vec3 rd);
void camera(out vec3 ro, out vec3 ta, out float fovY, out float focus, out float aperture);
int numLights();
int numBokeh();
float tMax();

vec3 calcNormal(vec3 p, float e) {
  const vec2 k = vec2(1, -1);
  return normalize(k.xyy * map(p + k.xyy * e).x + k.yyx * map(p + k.yyx * e).x + k.yxy * map(p + k.yxy * e).x + k.xxx * map(p + k.xxx * e).x);
}

bool march(vec3 ro, vec3 rd, float tmax, out float t, out float id) {
  t = 0.0; id = -1.0;
  for (int i = 0; i < 110; i++) {
    vec2 h = map(ro + rd * t);
    if (h.x < 0.00012 + 0.0004 * t) { id = h.y; return true; }
    t += h.x;
    if (t > tmax) break;
  }
  return false;
}
bool occluded(vec3 ro, vec3 rd, float tmax) {
  float t = 0.0;
  for (int i = 0; i < 70; i++) {
    float h = map(ro + rd * t).x;
    if (h < 0.0002) return true;
    t += max(h, 0.0006);
    if (t > tmax) return false;
  }
  return false;
}
float sphereHit(vec3 ro, vec3 rd, vec3 c, float r) {
  vec3 oc = ro - c; float b = dot(oc, rd), cc = dot(oc, oc) - r * r, h = b * b - cc;
  if (h < 0.0) return -1.0; h = sqrt(h); float t = -b - h; return t > 0.0 ? t : -1.0;
}

vec3 onb(vec3 n, vec3 v) { vec3 a = abs(n.y) < 0.99 ? vec3(0, 1, 0) : vec3(1, 0, 0); vec3 t = normalize(cross(a, n)), b = cross(n, t); return t * v.x + b * v.y + n * v.z; }
vec3 cosDir(vec3 n) { vec2 u = rnd2(); float r = sqrt(u.x), ph = 2.0 * PI * u.y; return onb(n, vec3(r * cos(ph), r * sin(ph), sqrt(1.0 - u.x))); }
float D_ggx(float nh, float a) { float a2 = a * a, d = nh * nh * (a2 - 1.0) + 1.0; return a2 / (PI * d * d); }
float G_smith(float nv, float nl, float a) { float k = a * 0.5; return (nv / (nv * (1.0 - k) + k)) * (nl / (nl * (1.0 - k) + k)); }
vec3 fresnel(vec3 f0, float c) { return f0 + (1.0 - f0) * pow(1.0 - c, 5.0); }

vec3 brdf(Mat m, vec3 n, vec3 v, vec3 l) {
  float nl = max(dot(n, l), 0.0), nv = max(dot(n, v), 1e-4);
  if (nl <= 0.0) return vec3(0);
  vec3 h = normalize(v + l); float a = max(m.rough * m.rough, 0.002);
  vec3 f0 = mix(vec3(0.04), m.base, m.metal);
  vec3 F = fresnel(f0, max(dot(v, h), 0.0));
  vec3 spec = F * D_ggx(max(dot(n, h), 0.0), a) * G_smith(nv, nl, a) / (4.0 * nv * nl + 1e-5);
  vec3 diff = (1.0 - F) * (1.0 - m.metal) * m.base / PI;
  return (diff + spec) * nl;
}

vec3 emitters(vec3 ro, vec3 rd, float tHit) {
  vec3 e = vec3(0); float best = tHit;
  for (int i = 0; i < numBokeh(); i++) { vec3 c, col; float r; bokeh(i, c, r, col); float t = sphereHit(ro, rd, c, r); if (t > 0.0 && t < best) { best = t; e = col; } }
  for (int i = 0; i < numLights(); i++) { vec3 c, col; float r; light(i, c, r, col); float t = sphereHit(ro, rd, c, r); if (t > 0.0 && t < best) { best = t; e = col; } }
  return e;
}

vec3 trace(vec3 ro, vec3 rd) {
  vec3 L = vec3(0), thr = vec3(1);
  bool sharp = true;                       // previous event could not be light-sampled
  for (int b = 0; b < 4; b++) {
    float t, id; bool hit = march(ro, rd, tMax(), t, id);
    if (sharp) L += thr * emitters(ro, rd, hit ? t : 1e9);
    if (!hit) { L += thr * sky(rd); break; }
    vec3 p = ro + rd * t;
    vec3 n = calcNormal(p, 0.00025 + 0.0004 * t);
    Mat m; m.base = vec3(0.5); m.metal = 0.0; m.rough = 0.5; m.emit = vec3(0); m.nbump = vec3(0);
    material(id, p, m);
    n = normalize(n + m.nbump);
    if (dot(n, rd) > 0.0) n = normalize(n - 1.02 * dot(n, rd) * rd);
    if (sharp) L += thr * m.emit;
    vec3 v = -rd;
    bool mirror = m.rough < 0.12;
    if (!mirror) {
      for (int i = 0; i < numLights(); i++) {
        vec3 c, col; float r; light(i, c, r, col);
        vec2 u = rnd2(); float z = 1.0 - 2.0 * u.x, s = sqrt(max(0.0, 1.0 - z * z));
        vec3 lp = c + r * vec3(s * cos(2.0 * PI * u.y), s * sin(2.0 * PI * u.y), z);
        vec3 ld = lp - p; float d = length(ld); ld /= d;
        if (dot(n, ld) > 0.0 && !occluded(p + n * 0.0008, ld, d - r * 1.05)) {
          L += thr * brdf(m, n, v, ld) * col * (PI * r * r) / (d * d);   // sphere seen as a disc of area pi r^2
        }
      }
    }
    // sample the next direction
    vec3 f0 = mix(vec3(0.04), m.base, m.metal);
    float nv = max(dot(n, v), 1e-4);
    vec3 Fv = fresnel(f0, nv);
    float pSpec = clamp(max(Fv.r, max(Fv.g, Fv.b)) * (1.0 - 0.6 * m.rough * (1.0 - m.metal)) + m.metal, 0.08, 1.0);
    if (m.metal > 0.99) pSpec = 1.0;
    vec3 nd;
    if (rnd() < pSpec) {
      float a = max(m.rough * m.rough, 0.002); vec2 u = rnd2();
      float ct = sqrt((1.0 - u.x) / (1.0 + (a * a - 1.0) * u.x)), st = sqrt(1.0 - ct * ct);
      vec3 h = onb(n, vec3(st * cos(2.0 * PI * u.y), st * sin(2.0 * PI * u.y), ct));
      nd = reflect(rd, h);
      float nl = dot(n, nd); if (nl <= 0.0) break;
      float vh = max(dot(v, h), 1e-4), nh = max(dot(n, h), 1e-4);
      thr *= fresnel(f0, vh) * G_smith(nv, nl, a) * vh / (nv * nh) / pSpec;
    } else {
      nd = cosDir(n);
      thr *= (1.0 - Fv) * (1.0 - m.metal) * m.base / (1.0 - pSpec);
    }
    sharp = mirror;
    ro = p + n * 0.0008; rd = nd;
    float q = max(thr.r, max(thr.g, thr.b));
    if (q < 0.02) break;
    thr = min(thr, vec3(4.0));
  }
  return L;
}

void main() {
  ivec2 px = ivec2(gl_FragCoord.xy);
  gS = pcg(uint(px.x) + pcg(uint(px.y) + pcg(uint(uSeed))));
  gT = uTime + (rnd() - 0.5) * uShutter;
  vec3 ro, ta; float fovY, focus, ap; camera(ro, ta, fovY, focus, ap);
  vec3 ww = normalize(ta - ro), uu = normalize(cross(ww, vec3(0, 1, 0))), vv = cross(uu, ww);
  vec2 uv = ((gl_FragCoord.xy + rnd2() - 0.5) * 2.0 - uRes) / uRes.y;
  vec3 rd = normalize(uv.x * uu + uv.y * vv + ww / tan(fovY * 0.5));
  vec3 fp = ro + rd * focus / dot(rd, ww);
  vec2 u = rnd2(); float r = sqrt(u.x) * ap, ph = 2.0 * PI * u.y;
  vec3 lo = ro + uu * r * cos(ph) + vv * r * sin(ph);
  vec3 c = trace(lo, normalize(fp - lo));
  c = min(c, vec3(60.0));                  // firefly clamp
  if (any(isnan(c)) || any(isinf(c))) c = vec3(0);
  fragColor = vec4(c, 1.0);
}
