#version 460 core

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform float uScrollY;
uniform float uMode;

out vec4 fragColor;

// ── Utility functions ──

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Simplex-like noise for organic patterns
float hash(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion (layered noise)
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

// Voronoi distance field
float voronoi(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float minDist = 1.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash(i + neighbor) * vec2(1.0); // pseudo-random point
            // Animate the cell points slightly
            point = 0.5 + 0.5 * sin(vec2(hash(i + neighbor), hash(i + neighbor + 0.5)) * 6.28 + uTime * 0.3);
            vec2 diff = neighbor + point - f;
            float dist = length(diff);
            minDist = min(minDist, dist);
        }
    }
    return minDist;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec3 color = vec3(0.0);
    float scrollShift = uScrollY * 0.001;

    // ── Mode 0: Holographic foil (oil-slick interference) ──
    if (uMode < 0.5) {
        // Organic noise-based surface instead of regular waves
        vec2 noiseUV = uv * 4.0 + vec2(uTime * 0.02, scrollShift);
        float n1 = fbm(noiseUV);
        float n2 = fbm(noiseUV + vec2(5.2, 1.3));

        // Thin-film interference angle from organic noise
        float viewAngle = n1 * 3.0 + n2 * 2.0 + scrollShift * 2.0;

        // Spectral color from interference
        float r = 0.5 + 0.5 * cos(viewAngle * 6.2832 + 0.0);
        float g = 0.5 + 0.5 * cos(viewAngle * 6.2832 + 2.094);
        float b = 0.5 + 0.5 * cos(viewAngle * 6.2832 + 4.189);
        color = vec3(r, g, b);

        // Specular highlights from noise peaks
        float spec = pow(max(0.0, n1 * 2.0 - 0.6), 3.0) * 0.5;
        color += vec3(spec);

        // Micro-sparkle
        float sparkle = hash(uv * 500.0 + uTime);
        sparkle = pow(sparkle, 20.0) * 0.3;
        color += vec3(sparkle);

        // Boost saturation
        float lum = dot(color, vec3(0.299, 0.587, 0.114));
        color = mix(vec3(lum), color, 1.5);
        color = clamp(color, 0.0, 1.0);
    }

    // ── Mode 1: Aurora ──
    else if (uMode < 1.5) {
        float n = fbm(vec2(uv.x * 3.0 + uTime * 0.2, uv.y * 0.5 + scrollShift));
        float w1 = sin(uv.x * 5.0 + uTime * 0.4 + n * 3.0) * 0.5 + 0.5;
        float w2 = sin(uv.x * 7.0 - uTime * 0.25 + 1.5) * 0.5 + 0.5;
        vec3 green = vec3(0.1, 0.9, 0.4);
        vec3 purple = vec3(0.6, 0.15, 0.9);
        vec3 blue = vec3(0.1, 0.4, 1.0);
        color = mix(green, purple, w1);
        color = mix(color, blue, w2 * 0.5);
        float curtain = smoothstep(0.0, 0.4, uv.y) * smoothstep(1.0, 0.5, uv.y);
        color *= curtain * (0.8 + 0.2 * n);
    }

    // ── Mode 2: Opalescent ──
    else if (uMode < 2.5) {
        float n = fbm(uv * 3.0 + uTime * 0.03);
        float angle = atan(uv.y - 0.5, uv.x - 0.5);
        float dist = length(uv - 0.5);
        float hue = fract(angle / 6.2832 + dist * 0.5 + n * 0.3 + scrollShift * 0.2);
        color = hsv2rgb(vec3(hue, 0.2 + n * 0.1, 0.95));
        float glow = 1.0 - smoothstep(0.0, 0.7, dist);
        color = mix(color, vec3(0.95, 0.93, 0.97), glow * 0.3);
    }

    // ── Mode 3: Prismatic ──
    else if (uMode < 3.5) {
        float n = noise(uv * 8.0 + uTime * 0.1);
        float bands = uv.y * 3.0 + uv.x * 1.5 + uTime * 0.1 + scrollShift * 0.6 + n * 0.2;
        float hue = fract(bands);
        color = hsv2rgb(vec3(hue, 0.8, 1.0));
        float refract = pow(abs(sin(bands * 3.14159)), 0.3);
        color *= 0.7 + 0.3 * refract;
    }

    // ── Mode 4: Ember ──
    else if (uMode < 4.5) {
        float n1 = fbm(uv * 6.0 + vec2(uTime * 0.4, uTime * 0.25));
        float n2 = fbm(uv * 8.0 - vec2(uTime * 0.15, uTime * 0.35));
        float glow = smoothstep(0.35, 0.65, n1) * smoothstep(0.3, 0.6, n2);
        vec3 warm = mix(vec3(0.85, 0.15, 0.02), vec3(1.0, 0.7, 0.15), glow);
        float vGlow = pow(1.0 - uv.y, 1.5);
        color = warm * (0.3 + 0.7 * vGlow);
        float spark = pow(max(0.0, n1 * n2 * 4.0 - 0.8), 4.0);
        color += vec3(spark, spark * 0.6, spark * 0.1);
    }

    // ── Mode 5: Mandelbrot Set ──
    else if (uMode < 5.5) {
        // Map UV to complex plane, zoom shifts with scroll
        float zoom = 2.5 - sin(scrollShift * 0.5 + uTime * 0.02) * 0.5;
        vec2 c = (uv - 0.5) * zoom + vec2(-0.5, 0.0);

        vec2 z = vec2(0.0);
        float iter = 0.0;
        const float maxIter = 64.0;

        for (float i = 0.0; i < maxIter; i++) {
            z = vec2(z.x * z.x - z.y * z.y + c.x, 2.0 * z.x * z.y + c.y);
            if (dot(z, z) > 4.0) {
                iter = i;
                break;
            }
            iter = i;
        }

        if (dot(z, z) <= 4.0) {
            color = vec3(0.0); // inside the set: black
        } else {
            // Smooth coloring using escape iteration
            float smooth_iter = iter - log2(log2(dot(z, z))) + 4.0;
            float hue = fract(smooth_iter * 0.02 + uTime * 0.01 + scrollShift * 0.1);
            float sat = 0.7 + 0.3 * sin(smooth_iter * 0.15);
            float val = 0.6 + 0.4 * sin(smooth_iter * 0.1);
            color = hsv2rgb(vec3(hue, sat, val));
        }
    }

    // ── Mode 6: Julia Set ──
    else if (uMode < 6.5) {
        // Animated Julia constant
        float t = uTime * 0.05 + scrollShift * 0.3;
        vec2 c = vec2(-0.7269 + 0.1 * sin(t), 0.1889 + 0.1 * cos(t * 0.7));

        vec2 z = (uv - 0.5) * 3.0;
        float iter = 0.0;
        const float maxIter = 48.0;

        for (float i = 0.0; i < maxIter; i++) {
            z = vec2(z.x * z.x - z.y * z.y + c.x, 2.0 * z.x * z.y + c.y);
            if (dot(z, z) > 4.0) {
                iter = i;
                break;
            }
            iter = i;
        }

        if (dot(z, z) <= 4.0) {
            color = vec3(0.02, 0.0, 0.05);
        } else {
            float smooth_iter = iter - log2(log2(dot(z, z))) + 4.0;
            float hue = fract(smooth_iter * 0.025 + 0.6 + uTime * 0.005);
            float sat = 0.6 + 0.4 * sin(smooth_iter * 0.2);
            float val = 0.5 + 0.5 * sin(smooth_iter * 0.15 + 1.0);
            color = hsv2rgb(vec3(hue, sat, val));
        }
    }

    // ── Mode 7: Oil Slick (realistic thin-film interference) ──
    else if (uMode < 7.5) {
        // Organic blobby surface using layered noise
        vec2 p = uv * 3.0;
        float n1 = fbm(p + vec2(uTime * 0.03, scrollShift * 0.5));
        float n2 = fbm(p * 1.5 + vec2(-uTime * 0.02, scrollShift * 0.3) + 3.7);
        float n3 = fbm(p * 0.8 + vec2(uTime * 0.01, -scrollShift * 0.2) + 7.1);

        // Film thickness varies organically
        float thickness = n1 * 0.4 + n2 * 0.35 + n3 * 0.25;
        thickness = thickness * 4.0 + scrollShift;

        // Thin-film interference: wavelength-dependent reflection
        float r = pow(sin(thickness * 6.2832 * 1.0), 2.0); // red wavelength
        float g = pow(sin(thickness * 6.2832 * 1.2), 2.0); // green (shorter)
        float b = pow(sin(thickness * 6.2832 * 1.45), 2.0); // blue (shortest)
        color = vec3(r, g, b);

        // Darken "thick" areas, brighten "thin" areas (oil pool effect)
        float depth = smoothstep(0.3, 0.7, n1);
        color *= 0.5 + 0.5 * depth;

        // Subtle surface sheen
        float sheen = pow(max(0.0, dot(normalize(vec2(n2 - 0.5, n3 - 0.5)), vec2(0.707))), 4.0);
        color += vec3(sheen * 0.15);
    }

    // ── Mode 8: Voronoi Crystals ──
    else if (uMode < 8.5) {
        vec2 p = uv * 5.0 + vec2(uTime * 0.05, scrollShift * 0.3);

        float v = voronoi(p);
        float v2 = voronoi(p * 1.5 + 3.0);

        // Color based on cell distance
        float hue = fract(v * 2.0 + v2 * 0.5 + uTime * 0.02 + scrollShift * 0.1);
        float sat = 0.5 + 0.3 * v;
        float val = 0.3 + 0.7 * smoothstep(0.0, 0.3, v);

        color = hsv2rgb(vec3(hue, sat, val));

        // Cell edges glow
        float edge = smoothstep(0.05, 0.0, v);
        color += vec3(edge * 0.4);

        // Second layer for depth
        float edge2 = smoothstep(0.08, 0.02, v2);
        color += vec3(edge2 * 0.15);
    }

    // ── Mode 9: Plasma ──
    else {
        float t = uTime * 0.3;
        float s = scrollShift;

        float v1 = sin(uv.x * 10.0 + t);
        float v2 = sin(uv.y * 10.0 + t * 0.7);
        float v3 = sin((uv.x + uv.y) * 8.0 + t * 0.5 + s);
        float v4 = sin(length(uv - 0.5) * 12.0 - t * 0.8 + s * 0.5);

        float v = (v1 + v2 + v3 + v4) * 0.25;

        // Rich color palette
        color.r = 0.5 + 0.5 * sin(v * 3.14159 * 2.0 + 0.0);
        color.g = 0.5 + 0.5 * sin(v * 3.14159 * 2.0 + 2.094);
        color.b = 0.5 + 0.5 * sin(v * 3.14159 * 2.0 + 4.189);

        // Add some brightness variation
        float brightness = 0.7 + 0.3 * sin(v * 6.0 + t);
        color *= brightness;
    }

    // Output with premultiplied alpha
    fragColor = vec4(color * uIntensity, uIntensity);
}
