precision mediump float;

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;
const int MAX_ITERS = 8;
const float HALF_PI =  1.5707964;

const int iterations = 1;
const float distance = 12.0;
const float noise = 0.3;
const float displ = 1.75;
const float rota = 0.8;
const float light = 0.5;
const float ncolor = 0.05;
const float round = 0.6;
const float twist = 0.5;
const float size = 1.0;
const vec2 mouse_pos = vec2(0.0, 0.0);
const vec2 dimensions = vec2(1000.0, 1000.0);

uniform vec4 time;

varying vec3 vposition;
varying vec3 vcolor;


float iter_cyl(vec3 p, float init_d) {
    float d = init_d;
    float s = 1.0;
    for(int i = 0; i < MAX_ITERS; i++) {
        if(i > iterations + int(sin(time.x / 5.0) * 2.0)) return d;

        p *= 3.0;
        s *= 3.0;

        float xy = dot(p.xy,p.xy);
        float xz = dot(p.xz,p.xz);
        float yz = dot(p.yz,p.yz);
        float d2 = (sqrt(min(xy,min(xz,yz))) - 1.0) / s;

        d = max(d,-d2);
        p = mod(p + 1.0, 2.0) - 1.0;
    }
    return d;
}

float sphere(vec3 p, float s) {
    return length(p) - s;
}

float roundbox( vec3 p, vec3 b, float r ) {
    return length(max(abs(p)-b,0.0))-r;
}

float disp(vec3 p, float amt) {
    return sin(amt*p.x)*sin(amt*p.y)*sin(amt*p.z);
}

mat3 rotateY(float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat3(
        vec3(c, 0, s),
        vec3(0, 1, 0),
        vec3(-s, 0, c)
    );
}

vec3 twist_pos(vec3 p) {
    float c = cos(twist*p.y);
    float s = sin(twist*p.y);
    mat2  m = mat2(c,-s,s,c);
    return vec3(m*p.xz,p.y);
}

float scene(vec3 p) {
    vec3 rp = twist_pos(rotateY(time.x + sin(time.x)) * p);
    p = twist_pos(p * (0.14 + abs(tan(time.x / 4.0))));
    return iter_cyl(
        p,
        roundbox(
            rp + disp(p, displ),
            vec3(size),
            round + 0.8 + cos(time.x / 6.69) * 0.5
        )
    );
}

float shortest_dist(vec3 eye, vec3 dir, float start, float end) {
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = scene(eye + depth * dir);
        if (dist < EPSILON || depth >=  end) break;
        depth += dist / (1.0 + displ);
    }
    return depth;
}

vec3 estimate_normal(vec3 p) {
    vec2 e = vec2(1.0,-1.0)*0.5773*0.0005;
    return normalize( e.xyy * scene(p + e.xyy) +
                      e.yyx * scene(p + e.yyx) +
                      e.yxy * scene(p + e.yxy) +
                      e.xxx * scene(p + e.xxx) );
}

vec3 phong_contrib(vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye,
                          vec3 light_pos, vec3 light_intensity) {
    vec3 N = estimate_normal(p);
    vec3 L = normalize(light_pos - p);
    vec3 V = normalize(eye - p);
    vec3 R = normalize(reflect(-L, N));

    float dotLN = dot(L, N);
    float dotRV = dot(R, V);

    if (dotLN < 0.0) {
        return vec3(0.0, 0.0, 0.0);
    }

    if (dotRV < 0.0) {
        return light_intensity * (k_d * dotLN);
    }
    return light_intensity * (k_d * dotLN + k_s * pow(dotRV, alpha));
}


float softshadow(vec3 eye, vec3 dir, float mint, float tmax ) {
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 16; i++) {
        float h = scene(eye + dir * t);
        res = min(res, 8.0 * h / t);
        t += clamp(h, 0.02, 0.10);
        if(h < 0.001 || t > tmax) break;
    }
    return clamp(res, 0.0, 1.0);
}


float calc_AO(vec3 pos, vec3 nor) {
    float occ = 0.0;
    float sca = 1.0;
    for(int i=0; i<5; i++) {
        float hr = 0.01 + 0.12*float(i)/4.0;
        vec3 aopos =  nor * hr + pos;
        float dd = scene(aopos);
        occ += -(dd-hr)*sca;
        sca *= 0.95;
    }
    return clamp( 1.0 - 3.0*occ, 0.0, 1.0 );
}

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec3 lighting(vec3 k_a, vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye) {
    const vec3 ambient_light = vec3(0.6);
    vec3 color = ambient_light * k_a;
    vec3 normal = estimate_normal(p);

    color = mix(color, normal, ncolor);
    color = mix(color, vec3(1.0), 0.5);

    float occ = calc_AO(p, normal);

    vec3 light_pos = vec3(4.0 * sin(time.x),
                          5.0,
                          4.0 * cos(time.x));
    vec3 light_intensity = vec3(light);

    color += phong_contrib(k_d, k_s, alpha, p, eye,
                                  light_pos,
                                  light_intensity);
    color = mix(
        color,
        color * occ * softshadow(p, normalize(light_pos), 0.02, 5.0),
        light + tan(time.x / 7.2) * 4.0
    );

    color = mix(color, vec3(rand(vposition.xy * time.x)), noise);

    return color;
}


vec4 render(vec3 cam_pos, vec3 v_dir) {
    float dist = shortest_dist(cam_pos, v_dir, MIN_DIST, MAX_DIST);

    if (dist > MAX_DIST - EPSILON) {
        return vec4(0.0, 0.0, 0.0, 0.0);
    }

    vec3 p = cam_pos + dist * v_dir;
    vec3 color = lighting(vec3(0.2), vec3(0.2), vec3(1.0), 20.0, p, cam_pos);
    return vec4(color, 1.0);
}

mat4 view_matrix(vec3 eye, vec3 center, vec3 up) {
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat4(
        vec4(s, 0.0),
        vec4(u, 0.0),
        vec4(-f, 0.0),
        vec4(0.0, 0.0, 0.0, 1)
    );
}

vec3 ray_dir(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

void main() {
    vec3 dir = ray_dir(45.0, dimensions, vposition.xy * dimensions + (dimensions / 2.0));

    vec3 input_cam_pos = vec3(-1.0, 1.0, -1.0) * cos(time.x / 25.0);
    vec3 cam_pos = vec3(
        cos(input_cam_pos.x) * cos(input_cam_pos.y),
        sin(input_cam_pos.y),
        sin(input_cam_pos.x) * cos(input_cam_pos.y)
    ) * distance;

    mat4 view_mat = view_matrix(cam_pos, vec3(0.0), vec3(0.0, 1.0, 0.0));
    vec3 v_dir = (view_mat * vec4(dir, 0.0)).xyz;

    gl_FragColor = render(cam_pos, v_dir);
}
