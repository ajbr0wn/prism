#version 460 core

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uIntensity;
uniform float uScrollY;
uniform float uMode;

out vec4 fragColor;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec3 color = vec3(0.0);

    // Mode 0: Holographic - rainbow foil shimmer
    if (uMode < 0.5) {
        float diagonal = uv.x * 0.6 + uv.y * 0.4;
        float hue = fract(diagonal * 2.0 + uTime * 0.08 + uScrollY * 0.0003);
        color = hsv2rgb(vec3(hue, 0.65, 0.9));

        // Fine shimmer lines
        float shimmer = sin((uv.x + uv.y) * 80.0 + uTime * 3.0) * 0.04;
        color += shimmer;
    }

    // Mode 1: Aurora - flowing northern lights
    else if (uMode < 1.5) {
        float w1 = sin(uv.x * 5.0 + uTime * 0.4 + uScrollY * 0.0008) * 0.5 + 0.5;
        float w2 = sin(uv.x * 7.0 - uTime * 0.25 + 1.5) * 0.5 + 0.5;
        vec3 green = vec3(0.15, 0.85, 0.45);
        vec3 purple = vec3(0.55, 0.2, 0.85);
        vec3 blue = vec3(0.15, 0.45, 0.95);
        color = mix(green, purple, w1);
        color = mix(color, blue, w2 * 0.5);
        float fade = smoothstep(0.0, 0.45, uv.y) * smoothstep(1.0, 0.55, uv.y);
        color *= fade;
    }

    // Mode 2: Opalescent - soft swirling pastels
    else if (uMode < 2.5) {
        float angle = atan(uv.y - 0.5, uv.x - 0.5);
        float dist = length(uv - 0.5);
        float hue = fract(angle / 6.2832 + dist * 0.5 + uTime * 0.04 + uScrollY * 0.0002);
        color = hsv2rgb(vec3(hue, 0.22, 0.95));
    }

    // Mode 3: Prismatic - vivid rainbow bands
    else if (uMode < 3.5) {
        float bands = uv.y * 3.0 + uv.x * 1.5 + uTime * 0.1 + uScrollY * 0.0006;
        float hue = fract(bands);
        color = hsv2rgb(vec3(hue, 0.8, 1.0));
    }

    // Mode 4: Ember - warm glowing particles
    else {
        float n = sin(uv.x * 12.0 + uTime * 0.8) * sin(uv.y * 12.0 + uTime * 0.5);
        float glow = smoothstep(0.2, 0.0, abs(n));
        vec3 warm = mix(vec3(0.85, 0.2, 0.05), vec3(1.0, 0.65, 0.15), glow);
        float vGlow = pow(1.0 - uv.y, 1.5);
        color = warm * (0.35 + 0.65 * vGlow);
    }

    // Output with premultiplied alpha
    fragColor = vec4(color * uIntensity, uIntensity);
}
