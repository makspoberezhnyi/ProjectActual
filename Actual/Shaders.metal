#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// MARK: - Constants & Utilities
constant float TWO_PI = 6.28318530717958647692f;
constant float PI = 3.14159265358979323846f;

inline float glsl_mod(float x, float y) {
    return x - y * floor(x / y);
}

inline float2 glsl_mod(float2 x, float y) {
    return x - y * floor(x / y);
}

inline float2 glsl_mod(float2 x, float2 y) {
    return x - y * floor(x / y);
}

inline float3 glsl_mod(float3 x, float y) {
    return x - y * floor(x / y);
}

inline float3 glsl_mod(float3 x, float3 y) {
    return x - y * floor(x / y);
}

inline float4 glsl_mod(float4 x, float y) {
    return x - y * floor(x / y);
}

inline float2 rotate(float2 uv, float th) {
    float c = cos(th);
    float s = sin(th);
    return float2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
}

// MARK: - Procedural Hash & Noise
inline float hash11(float p) {
    p = fract(p * 0.3183099f) + 0.1f;
    p *= p + 19.19f;
    return fract(p * p);
}

inline float hash21(float2 p) {
    p = fract(p * float2(0.3183099f, 0.3678794f)) + 0.1f;
    p += dot(p, p + 19.19f);
    return fract(p.x * p.y);
}

inline float2 hash22(float2 p) {
    p = fract(p * float2(0.3183099f, 0.3678794f)) + 0.1f;
    p += dot(p, p.yx + 19.19f);
    return fract(float2(p.x * p.y, p.x + p.y));
}

inline float valueNoise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    float a = hash21(i);
    float b = hash21(i + float2(1.0f, 0.0f));
    float c = hash21(i + float2(0.0f, 1.0f));
    float d = hash21(i + float2(1.0f, 1.0f));
    float2 u = f * f * (3.0f - 2.0f * f);
    float x1 = mix(a, b, u.x);
    float x2 = mix(c, d, u.x);
    return mix(x1, x2, u.y);
}

inline float4 fbmR(float2 n0, float2 n1, float2 n2, float2 n3) {
    float amplitude = 0.2f;
    float4 total = float4(0.0f);
    for (int i = 0; i < 3; i++) {
        n0 = rotate(n0, 0.3f);
        n1 = rotate(n1, 0.3f);
        n2 = rotate(n2, 0.3f);
        n3 = rotate(n3, 0.3f);
        total.x += valueNoise(n0) * amplitude;
        total.y += valueNoise(n1) * amplitude;
        total.z += valueNoise(n2) * amplitude;
        total.w += valueNoise(n3) * amplitude;
        n0 *= 1.99f;
        n1 *= 1.99f;
        n2 *= 1.99f;
        n3 *= 1.99f;
        amplitude *= 0.6f;
    }
    return total;
}

// MARK: - 2D Simplex Noise
inline float3 permute(float3 x) {
    return glsl_mod(((x * 34.0f) + 1.0f) * x, 289.0f);
}

inline float snoise(float2 v) {
    const float4 C = float4(0.211324865405187f, 0.366025403784439f, -0.577350269189626f, 0.024390243902439f);
    float2 i = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);
    float2 i1 = (x0.x > x0.y) ? float2(1.0f, 0.0f) : float2(0.0f, 1.0f);
    float4 x12 = float4(x0.xy, x0.xy) + C.xxzz;
    x12.xy -= i1;
    i = glsl_mod(i, 289.0f);
    float3 p = permute(permute(i.y + float3(0.0f, i1.y, 1.0f)) + i.x + float3(0.0f, i1.x, 1.0f));
    float3 m = max(0.5f - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0f);
    m = m * m;
    m = m * m;
    float3 x = 2.0f * fract(p * C.www) - 1.0f;
    float3 h = abs(x) - 0.5f;
    float3 ox = floor(x + 0.5f);
    float3 a0 = x - ox;
    m *= 1.79284291400159f - 0.85373472095314f * (a0 * a0 + h * h);
    float3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0f * dot(m, g);
}

// MARK: - Liquid Metal Internal Helpers
inline float getLiquidMetalColorChanges(float c1, float c2, float stripe_p, float3 w, float blur, float bump, float tint, float tintAlpha) {
    float ch = mix(c2, c1, smoothstep(0.0f, 2.0f * blur, stripe_p));

    float border = w[0];
    ch = mix(ch, c2, smoothstep(border, border + 2.0f * blur, stripe_p));

    border = w[0] + 0.4f * (1.0f - bump) * w[1];
    ch = mix(ch, c1, smoothstep(border, border + 2.0f * blur, stripe_p));

    border = w[0] + 0.5f * (1.0f - bump) * w[1];
    ch = mix(ch, c2, smoothstep(border, border + 2.0f * blur, stripe_p));

    border = w[0] + w[1];
    ch = mix(ch, c1, smoothstep(border, border + 2.0f * blur, stripe_p));

    float gradient_t = (stripe_p - w[0] - w[1]) / max(w[2], 0.0001f);
    float gradient = mix(c1, c2, smoothstep(0.0f, 1.0f, gradient_t));
    ch = mix(ch, gradient, smoothstep(border, border + 0.5f * blur, stripe_p));

    // Color burn tint
    ch = mix(ch, 1.0f - min(1.0f, (1.0f - ch) / max(tint, 0.0001f)), tintAlpha);
    return ch;
}

// =============================================================================
// 1. LIQUID METAL SHADER (SwiftUI Stitchable)
// =============================================================================
[[stitchable]] half4 liquidMetalShader(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float softness,
    float repetition,
    float shiftRed,
    float shiftBlue,
    float distortion,
    float contour,
    float angleDeg,
    float shape
) {
    if (size.x <= 0.0f || size.y <= 0.0f) return currentColor;

    float2 uv = position / size;
    const float firstFrameOffset = 2.8f;
    float t = 0.3f * (time + firstFrameOffset);

    float cycleWidth = max(repetition, 0.1f);
    float edge = 0.0f;

    float2 rotatedUV = uv - 0.5f;
    float angle = (-angleDeg + 70.0f) * PI / 180.0f;
    float cosA = cos(angle);
    float sinA = sin(angle);
    rotatedUV = float2(
        rotatedUV.x * cosA - rotatedUV.y * sinA,
        rotatedUV.x * sinA + rotatedUV.y * cosA
    ) + 0.5f;

    if (shape < 1.0f) {
        // Full-fill canvas
        float2 borderUV = uv;
        float2 mask = min(borderUV, 1.0f - borderUV);
        float2 pixelThickness = min(250.0f / size, float2(0.5f));
        float maskX = smoothstep(0.0f, pixelThickness.x, mask.x);
        float maskY = smoothstep(0.0f, pixelThickness.y, mask.y);
        maskX = pow(max(maskX, 0.0f), 0.25f);
        maskY = pow(max(maskY, 0.0f), 0.25f);
        edge = clamp(1.0f - maskX * maskY, 0.0f, 1.0f);
        cycleWidth *= 2.0f;
    } else if (shape < 2.0f) {
        // Circle / Capsule
        float2 shapeUV = uv - 0.5f;
        shapeUV *= 0.67f;
        edge = pow(clamp(3.0f * length(shapeUV), 0.0f, 1.0f), 18.0f);
    } else if (shape < 3.0f) {
        // Daisy organic petal shape
        float2 shapeUV = uv - 0.5f;
        shapeUV *= 1.68f;
        float r = length(shapeUV) * 2.0f;
        float a = atan2(shapeUV.y, shapeUV.x) + 0.2f;
        r *= (1.0f + 0.05f * sin(3.0f * a + 2.0f * t));
        float f = abs(cos(a * 3.0f));
        edge = smoothstep(f, f + 0.7f, r);
        edge *= edge;
        uv *= 0.8f;
        cycleWidth *= 1.6f;
    } else if (shape < 4.0f) {
        // Diamond
        float2 shapeUV = uv - 0.5f;
        shapeUV = rotate(shapeUV, 0.25f * PI);
        shapeUV *= 1.42f;
        shapeUV += 0.5f;
        float2 mask = min(shapeUV, 1.0f - shapeUV);
        float2 pixelThickness = float2(0.15f);
        float maskX = smoothstep(0.0f, pixelThickness.x, mask.x);
        float maskY = smoothstep(0.0f, pixelThickness.y, mask.y);
        maskX = pow(max(maskX, 0.0f), 0.25f);
        maskY = pow(max(maskY, 0.0f), 0.25f);
        edge = clamp(1.0f - maskX * maskY, 0.0f, 1.0f);
    } else {
        // Metaballs
        float2 shapeUV = uv - 0.5f;
        shapeUV *= 1.3f;
        edge = 0.0f;
        for (int i = 0; i < 5; i++) {
            float fi = float(i);
            float speed = 1.5f + (2.0f / 3.0f) * sin(fi * 12.345f);
            float angleVal = -fi * 1.5f;
            float2 dir1 = float2(cos(angleVal), sin(angleVal));
            float2 dir2 = float2(cos(angleVal + 1.57f), sin(angleVal + 1.0f));
            float2 traj = 0.4f * (dir1 * sin(t * speed + fi * 1.23f) + dir2 * cos(t * (speed * 0.7f) + fi * 2.17f));
            float d = length(shapeUV + traj);
            edge += pow(1.0f - clamp(d, 0.0f, 1.0f), 4.0f);
        }
        edge = 1.0f - smoothstep(0.65f, 0.9f, edge);
        edge = pow(max(edge, 0.0f), 4.0f);
    }

    edge = mix(smoothstep(0.9f - 2.0f * fwidth(edge), 0.9f, edge), edge, smoothstep(0.0f, 0.4f, contour));

    float opacity = 1.0f - smoothstep(0.9f - 2.0f * fwidth(edge), 0.9f, edge);
    if (shape < 2.0f) {
        edge = 1.2f * edge;
    } else {
        edge = 1.8f * pow(max(edge, 0.0f), 1.5f);
    }

    float diagBLtoTR = rotatedUV.x - rotatedUV.y;
    float diagTLtoBR = rotatedUV.x + rotatedUV.y;

    float3 color1 = float3(0.98f, 0.98f, 1.0f);
    float3 color2 = float3(0.10f, 0.10f, 0.10f + 0.10f * smoothstep(0.7f, 1.3f, diagTLtoBR));

    float2 grad_uv = uv - 0.5f;
    float dist = length(grad_uv + float2(0.0f, 0.2f * diagBLtoTR));
    grad_uv = rotate(grad_uv, (0.25f - 0.2f * diagBLtoTR) * PI);
    float direction = grad_uv.x;

    float bump = pow(max(1.8f * dist, 0.0f), 1.2f);
    bump = 1.0f - bump;
    bump *= pow(max(uv.y, 0.0001f), 0.3f);

    float thin_strip_1_ratio = 0.12f / cycleWidth * (1.0f - 0.4f * bump);
    float thin_strip_2_ratio = 0.07f / cycleWidth * (1.0f + 0.4f * bump);
    float wide_strip_ratio = (1.0f - thin_strip_1_ratio - thin_strip_2_ratio);

    float thin_strip_1_width = cycleWidth * thin_strip_1_ratio;
    float thin_strip_2_width = cycleWidth * thin_strip_2_ratio;

    float noise = snoise(uv - t);
    edge += (1.0f - edge) * distortion * noise;

    direction += diagBLtoTR;
    direction -= 2.0f * noise * diagBLtoTR * (smoothstep(0.0f, 1.0f, edge) * (1.0f - smoothstep(0.0f, 1.0f, edge)));
    direction *= mix(1.0f, 1.0f - edge, smoothstep(0.5f, 1.0f, contour));
    direction -= 1.7f * edge * smoothstep(0.5f, 1.0f, contour);
    direction += 0.2f * pow(max(contour, 0.0f), 4.0f) * (1.0f - smoothstep(0.0f, 1.0f, edge));

    bump *= clamp(pow(max(uv.y, 0.0001f), 0.1f), 0.3f, 1.0f);
    direction *= (0.1f + (1.1f - edge) * bump);
    direction *= (0.4f + 0.6f * (1.0f - smoothstep(0.5f, 1.0f, edge)));
    direction += 0.18f * (smoothstep(0.1f, 0.2f, uv.y) * (1.0f - smoothstep(0.2f, 0.4f, uv.y)));
    direction += 0.03f * (smoothstep(0.1f, 0.2f, 1.0f - uv.y) * (1.0f - smoothstep(0.2f, 0.4f, 1.0f - uv.y)));

    direction *= (0.5f + 0.5f * pow(uv.y, 2.0f));
    direction *= cycleWidth;
    direction -= t;

    float colorDispersion = clamp(1.0f - bump, 0.0f, 1.0f);
    float dispersionRed = colorDispersion;
    dispersionRed += 0.03f * bump * noise;
    dispersionRed += 5.0f * (smoothstep(-0.1f, 0.2f, uv.y) * (1.0f - smoothstep(0.1f, 0.5f, uv.y))) * (smoothstep(0.4f, 0.6f, bump) * (1.0f - smoothstep(0.4f, 1.0f, bump)));
    dispersionRed -= diagBLtoTR;

    float dispersionBlue = colorDispersion * 1.3f;
    dispersionBlue += (smoothstep(0.0f, 0.4f, uv.y) * (1.0f - smoothstep(0.1f, 0.8f, uv.y))) * (smoothstep(0.4f, 0.6f, bump) * (1.0f - smoothstep(0.4f, 0.8f, bump)));
    dispersionBlue -= 0.2f * edge;

    dispersionRed *= (shiftRed / 20.0f);
    dispersionBlue *= (shiftBlue / 20.0f);

    float blur = softness / 15.0f;

    float3 w = float3(thin_strip_1_width, thin_strip_2_width, wide_strip_ratio);
    w[1] -= 0.02f * smoothstep(0.0f, 1.0f, edge + bump);

    float stripe_r = fract(direction + dispersionRed);
    float r = getLiquidMetalColorChanges(color1.r, color2.r, stripe_r, w, blur + fwidth(stripe_r), bump, 1.0f, 0.0f);

    float stripe_g = fract(direction);
    float g = getLiquidMetalColorChanges(color1.g, color2.g, stripe_g, w, blur + fwidth(stripe_g), bump, 1.0f, 0.0f);

    float stripe_b = fract(direction - dispersionBlue);
    float b = getLiquidMetalColorChanges(color1.b, color2.b, stripe_b, w, blur + fwidth(stripe_b), bump, 1.0f, 0.0f);

    float3 color = float3(r, g, b) * opacity;

    // Color banding dither
    color += (1.0f / 256.0f) * (fract(sin(dot(0.014f * position, float2(12.9898f, 78.233f))) * 43758.5453123f) - 0.5f);

    return half4(half3(color), half(opacity));
}

// =============================================================================
// 2. MESH GRADIENT SHADER (SwiftUI Stitchable)
// =============================================================================
inline float2 getMeshPointPosition(int i, float t) {
    float a = float(i) * 0.37f;
    float b = 0.6f + fract(float(i) / 3.0f) * 0.9f;
    float c = 0.8f + fract(float(i + 1) / 4.0f);

    float x = sin(t * b + a);
    float y = cos(t * c + a * 1.5f);

    return 0.5f + 0.5f * float2(x, y);
}

[[stitchable]] half4 meshGradientShader(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float distortion,
    float swirl,
    float grainMixer,
    float grainOverlay,
    half4 color0,
    half4 color1,
    half4 color2,
    half4 color3,
    half4 color4,
    half4 color5
) {
    if (size.x <= 0.0f || size.y <= 0.0f) return currentColor;

    float2 uv = position / size;
    float2 grainUV = uv * 1000.0f;

    float grain = valueNoise(grainUV);
    float mixerGrain = 0.4f * grainMixer * (grain - 0.5f);

    const float firstFrameOffset = 41.5f;
    float t = 0.5f * (time + firstFrameOffset);

    float radius = smoothstep(0.0f, 1.0f, length(uv - 0.5f));
    float center = 1.0f - radius;

    for (float i = 1.0f; i <= 2.0f; i += 1.0f) {
        uv.x += distortion * center / i * sin(t + i * 0.4f * smoothstep(0.0f, 1.0f, uv.y)) * cos(0.2f * t + i * 2.4f * smoothstep(0.0f, 1.0f, uv.y));
        uv.y += distortion * center / i * cos(t + i * 2.0f * smoothstep(0.0f, 1.0f, uv.x));
    }

    float2 uvRotated = uv - 0.5f;
    float angle = 3.0f * swirl * radius;
    uvRotated = rotate(uvRotated, -angle) + 0.5f;

    float3 colorSum = float3(0.0f);
    float opacitySum = 0.0f;
    float totalWeight = 0.0f;

    half4 colors[6] = { color0, color1, color2, color3, color4, color5 };

    for (int i = 0; i < 6; i++) {
        float2 pos = getMeshPointPosition(i, t) + mixerGrain;
        float3 colorFraction = float3(colors[i].rgb) * float(colors[i].a);
        float opacityFraction = float(colors[i].a);

        float dist = length(uvRotated - pos);
        dist = pow(max(dist, 0.0f), 3.5f);
        float weight = 1.0f / (dist + 1e-3f);

        colorSum += colorFraction * weight;
        opacitySum += opacityFraction * weight;
        totalWeight += weight;
    }

    colorSum /= max(1e-4f, totalWeight);
    opacitySum /= max(1e-4f, totalWeight);

    // Dynamic Grain Overlay
    float grainOverlayVal = valueNoise(rotate(grainUV, 1.0f) + float2(3.0f));
    grainOverlayVal = mix(grainOverlayVal, valueNoise(rotate(grainUV, 2.0f) + float2(-1.0f)), 0.5f);
    grainOverlayVal = pow(max(grainOverlayVal, 0.0f), 1.3f);

    float grainOverlayV = grainOverlayVal * 2.0f - 1.0f;
    float3 grainOverlayColor = float3(step(0.0f, grainOverlayV));
    float grainOverlayStrength = grainOverlay * abs(grainOverlayV);
    grainOverlayStrength = pow(max(grainOverlayStrength, 0.0f), 0.8f);

    colorSum = mix(colorSum, grainOverlayColor, 0.35f * grainOverlayStrength);
    opacitySum += 0.5f * grainOverlayStrength;
    opacitySum = clamp(opacitySum, 0.0f, 1.0f);

    return half4(half3(colorSum), half(opacitySum));
}

// =============================================================================
// 3. GRAIN GRADIENT SHADER (SwiftUI Stitchable)
// =============================================================================
[[stitchable]] half4 grainGradientShader(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float softness,
    float intensity,
    float noiseAmount,
    float shapeMode,
    half4 colorBack,
    half4 c0,
    half4 c1,
    half4 c2,
    half4 c3
) {
    if (size.x <= 0.0f || size.y <= 0.0f) return currentColor;

    float2 shape_uv = (position - size * 0.5f) / min(size.x, size.y);
    float2 grain_uv = shape_uv * 100.0f;

    const float firstFrameOffset = 7.0f;
    float t = 0.1f * (time + firstFrameOffset);

    float shape = 0.0f;

    if (shapeMode < 1.5f) {
        // Sine wave
        float wave = cos(0.5f * shape_uv.x - 4.0f * t) * sin(1.5f * shape_uv.x + 2.0f * t) * (0.75f + 0.25f * cos(6.0f * t));
        shape = 1.0f - smoothstep(-1.0f, 1.0f, shape_uv.y + wave);
    } else if (shapeMode < 2.5f) {
        // Dots / Grid
        float stripeIdx = floor(2.0f * shape_uv.x / TWO_PI);
        float rand = hash11(stripeIdx * 100.0f);
        rand = sign(rand - 0.5f) * pow(4.0f * abs(rand), 0.3f);
        shape = sin(shape_uv.x) * cos(shape_uv.y - 5.0f * rand * t);
        shape = pow(abs(shape), 4.0f);
    } else if (shapeMode < 3.5f) {
        // Ripple
        shape_uv *= 2.0f;
        float dist = length(0.4f * shape_uv);
        float waves = sin(pow(max(dist, 0.0f), 1.2f) * 5.0f - 3.0f * t) * 0.5f + 0.5f;
        shape = waves;
    } else if (shapeMode < 4.5f) {
        // Blob
        float blobT = t * 2.0f;
        float2 f1_traj = 0.25f * float2(1.3f * sin(blobT), 0.2f + 1.3f * cos(0.6f * blobT + 4.0f));
        float2 f2_traj = 0.20f * float2(1.2f * sin(-blobT), 1.3f * sin(1.6f * blobT));
        float2 f3_traj = 0.25f * float2(1.7f * cos(-0.6f * blobT), cos(-1.6f * blobT));
        float2 f4_traj = 0.30f * float2(1.4f * cos(0.8f * blobT), 1.2f * sin(-0.6f * blobT - 3.0f));

        shape = 0.5f * pow(1.0f - clamp(length(shape_uv + f1_traj), 0.0f, 1.0f), 5.0f);
        shape += 0.5f * pow(1.0f - clamp(length(shape_uv + f2_traj), 0.0f, 1.0f), 5.0f);
        shape += 0.5f * pow(1.0f - clamp(length(shape_uv + f3_traj), 0.0f, 1.0f), 5.0f);
        shape += 0.5f * pow(1.0f - clamp(length(shape_uv + f4_traj), 0.0f, 1.0f), 5.0f);

        shape = smoothstep(0.0f, 0.9f, shape);
        float edge = smoothstep(0.25f, 0.30f, shape);
        shape = mix(0.0f, shape, edge);
    } else {
        // Sphere
        shape_uv *= 2.0f;
        float d = 1.0f - pow(length(shape_uv), 2.0f);
        float3 pos = float3(shape_uv, sqrt(max(d, 0.0f)));
        float3 lightPos = normalize(float3(cos(1.5f * t), 0.8f, sin(1.25f * t)));
        shape = 0.5f + 0.5f * dot(lightPos, pos);
        shape *= step(0.0f, d);
    }

    float baseNoise = snoise(grain_uv * 0.5f);
    float4 fbmVals = fbmR(
        0.002f * grain_uv + 10.0f,
        0.003f * grain_uv,
        0.001f * grain_uv,
        rotate(0.4f * grain_uv, 2.0f)
    );
    float grainDist = baseNoise * snoise(grain_uv * 0.2f) - fbmVals.x - fbmVals.y;
    float rawNoise = 0.75f * baseNoise - fbmVals.w - fbmVals.z;
    float noise = clamp(rawNoise, 0.0f, 1.0f);

    const float colorsCount = 4.0f;
    shape += intensity * 2.0f / colorsCount * (grainDist + 0.5f);
    shape += noiseAmount * 10.0f / colorsCount * noise;

    float aa = fwidth(shape);
    shape = clamp(shape - 0.5f / colorsCount, 0.0f, 1.0f);
    float totalShape = smoothstep(0.0f, softness + 2.0f * aa, clamp(shape * colorsCount, 0.0f, 1.0f));
    float mixer = shape * (colorsCount - 1.0f);

    half4 colors[4] = { c0, c1, c2, c3 };
    half4 gradient = colors[0];
    gradient.rgb *= gradient.a;

    for (int i = 1; i < 4; i++) {
        float localT = clamp(mixer - float(i - 1), 0.0f, 1.0f);
        localT = smoothstep(0.5f - 0.5f * softness - aa, 0.5f + 0.5f * softness + aa, localT);
        half4 c = colors[i];
        c.rgb *= c.a;
        gradient = mix(gradient, c, half(localT));
    }

    float3 color = float3(gradient.rgb) * totalShape;
    float opacity = float(gradient.a) * totalShape;

    float3 bgColor = float3(colorBack.rgb) * float(colorBack.a);
    color = color + bgColor * (1.0f - opacity);
    opacity = opacity + float(colorBack.a) * (1.0f - opacity);

    return half4(half3(color), half(opacity));
}
