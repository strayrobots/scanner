//
//  Shaders.metal
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/28/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

#include <metal_stdlib>
#import "ShaderTypes.h"

using namespace metal;

constant float MinDepth = 0.05;
constant float InvMaxDepth = 1.0 / 10.0;
constant float InvE3 = 1.0 / (M_E_F * M_E_F * M_E_F);

struct VertexIn {
    float2 vertexCoordinates [[attribute(0)]]; // Position index 0.
    float2 textureCoordinates [[attribute(1)]]; // Texture coordinate index 1.
};

struct VertexOut {
    float4 vertexCoordinate [[position]];
    float2 textureCoordinate;
};

struct ImageColorOut {
    float4 color;
    float2 textureCoordinate;
};

vertex VertexOut drawRectangle(const device VertexIn* vertexIn[[ buffer(0) ]],
    uint vertexIndex [[ vertex_id ]]) {
    VertexOut out;
    VertexIn v = vertexIn[vertexIndex];
    out.vertexCoordinate = float4(v.vertexCoordinates, 0.0, 1.0);
    out.textureCoordinate = v.textureCoordinates;
    return out;
}

fragment half4 displayTexture(VertexOut in [[stage_in]],
                            texture2d<float, access::sample> capturedImageTextureY [[ texture(kTextureIndexY) ]],
                            texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(kTextureIndexCbCr) ]]) {

    constexpr sampler colorSampler(address::clamp_to_edge, filter::linear);

    half4 ycbcr = half4(half(capturedImageTextureY.sample(colorSampler, in.textureCoordinate).r),
                        half2(capturedImageTextureCbCr.sample(colorSampler, in.textureCoordinate).rg), 1.0);

    const half4x4 ycbcrToRGBTransform = half4x4(
        half4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
        half4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
        half4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
        half4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );

    return ycbcrToRGBTransform * ycbcr;
}

fragment half4 depthFragment(VertexOut in [[stage_in]], depth2d<float, access::sample> depthFrame [[ texture(0) ]]) {
    constexpr sampler depthSampler(address::clamp_to_edge, filter::bicubic);
    float depth = depthFrame.sample(depthSampler, in.textureCoordinate);

    depth = max(depth - MinDepth, 0.0);
    depth = min(depth * InvMaxDepth, M_E_F - InvE3);
    half clamped = 0.1 + (1.0 - (log(InvE3 + depth) + 3.0) / 4.0) * 0.8;
    return half4(clamped, clamped, clamped, 1.0);
}
