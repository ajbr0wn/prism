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

    // Mode 0: Holographic foil
    // Simulates thin-film interference with specular highlights
    if (uMode < 0.5) {
        // Microscopic ridge pattern (simulates diffraction grating)
        float ridges = sin(uv.x * 45.0 + uv.y * 12.0) * 0.4
                     + sin(uv.x * 18.0 - uv.y * 30.0) * 0.35
                     + sin(uv.x * 8.0 + uv.y * 55.0) * 0.25;

        // View angle shifts with scroll and time
        float viewAngle = ridges + uScrollY * 0.002 + uTime * 0.06;

        // Thin-film interference: phase-shifted cosines for spectral color
        float r = 0.5 + 0.5 * cos(viewAngle * 6.2832 + 0.0);
        float g = 0.5 + 0.5 * cos(viewAngle * 6.2832 + 2.094);
        float b = 0.5 + 0.5 * cos(viewAngle * 6.2832 + 4.189);
        color = vec3(r, g, b);

        // Specular highlights (bright spots that shift with scroll)
        float spec = pow(max(0.0, cos(ridges * 3.0 + uScrollY * 0.003 + uTime * 0.1)), 12.0);
        color += vec3(spec * 0.4);

        // Fresnel-like effect: stronger color at certain angles
        float fresnel = 0.6 + 0.4 * pow(abs(sin(uv.y * 3.14159 + ridges * 0.5)), 0.8);
        color *= fresnel;

        // Subtle micro-shimmer (fine sparkle)
        float sparkle = sin(uv.x * 200.0 + uTime * 5.0) * sin(uv.y * 200.0 - uTime * 3.0);
        sparkle = max(0.0, sparkle) * 0.15;
        color += vec3(sparkle);

        // Boost saturation and contrast for that foil pop
        float luminance = dot(color, vec3(0.299, 0.587, 0.114));
        color = mix(vec3(luminance), color, 1.4); // boost saturation
        color = clamp(color, 0.0, 1.0);
    }

    // Mode 1: Aurora
    else if (uMode < 1.5) {
        float w1 = sin(uv.x * 5.0 + uTime * 0.4 + uScrollY * 0.0008) * 0.5 + 0.5;
        float w2 = sin(uv.x * 7.0 - uTime * 0.25 + 1.5) * 0.5 + 0.5;
        float w3 = sin(uv.y * 3.0 + uTime * 0.15) * 0.5 + 0.5;
        vec3 green = vec3(0.1, 0.9, 0.4);
        vec3 purple = vec3(0.6, 0.15, 0.9);
        vec3 blue = vec3(0.1, 0.4, 1.0);
        vec3 pink = vec3(0.9, 0.2, 0.5);
        color = mix(green, purple, w1);
        color = mix(color, blue, w2 * 0.5);
        color = mix(color, pink, w3 * 0.2);
        // Curtain-like vertical fade with movement
        float curtain = smoothstep(0.0, 0.4, uv.y) * smoothstep(1.0, 0.5, uv.y);
        float wave = sin(uv.x * 10.0 + uTime * 0.6) * 0.1;
        curtain *= (0.9 + wave);
        color *= curtain;
    }

    // Mode 2: Opalescent
    else if (uMode < 2.5) {
        float angle = atan(uv.y - 0.5, uv.x - 0.5);
        float dist = length(uv - 0.5);
        float hue = fract(angle / 6.2832 + dist * 0.5 + uTime * 0.04 + uScrollY * 0.0002);
        color = hsv2rgb(vec3(hue, 0.22, 0.95));
        // Add milky glow in center
        float glow = 1.0 - smoothstep(0.0, 0.7, dist);
        color = mix(color, vec3(0.95, 0.93, 0.97), glow * 0.3);
    }

    // Mode 3: Prismatic
    else if (uMode < 3.5) {
        float bands = uv.y * 3.0 + uv.x * 1.5 + uTime * 0.1 + uScrollY * 0.0006;
        float hue = fract(bands);
        color = hsv2rgb(vec3(hue, 0.8, 1.0));
        // Add light refraction effect
        float refract = pow(abs(sin(bands * 3.14159)), 0.3);
        color *= 0.7 + 0.3 * refract;
    }

    // Mode 4: Ember
    else {
        float n1 = sin(uv.x * 12.0 + uTime * 0.8) * sin(uv.y * 12.0 + uTime * 0.5);
        float n2 = sin(uv.x * 8.0 - uTime * 0.3) * sin(uv.y * 15.0 + uTime * 0.7);
        float glow = smoothstep(0.2, 0.0, abs(n1)) + smoothstep(0.3, 0.0, abs(n2)) * 0.5;
        vec3 warm = mix(vec3(0.85, 0.15, 0.02), vec3(1.0, 0.7, 0.15), glow);
        float vGlow = pow(1.0 - uv.y, 1.5);
        color = warm * (0.3 + 0.7 * vGlow);
        // Occasional bright spark
        float spark = pow(max(0.0, n1 * n2), 8.0) * 3.0;
        color += vec3(spark, spark * 0.6, spark * 0.1);
    }

    // Output with premultiplied alpha
    fragColor = vec4(color * uIntensity, uIntensity);
}
