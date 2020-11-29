//
//  Shaders.metal
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/28/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct ImageColorInOut {
    float4 color;
};

vertex float4 drawRectangle(const device packed_float3* vertexArray [[ buffer(0) ]],
    unsigned int vertexIndex [[ vertex_id ]]) {
    return float4(vertexArray[vertexIndex], 1.0);
}

fragment half4 constantColor() {
    return half4(0.2, 0.2, 0.8, 1.0);
}

//fragment float4 renderImage(ImageColorInOut in [[stage_in]],
//                                            texture2d<float, access::sample> capturedImageTextureY [[ texture(kTextureIndexY) ]],
//                                            texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(kTextureIndexCbCr) ]]) {
//
//    constexpr sampler colorSampler(mip_filter::linear,
//                                   mag_filter::linear,
//                                   min_filter::linear);
//
//    const float4x4 ycbcrToRGBTransform = float4x4(
//        float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
//        float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
//        float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
//        float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
//    );
//
//    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
//    float4 ycbcr = float4(capturedImageTextureY.sample(colorSampler, in.texCoord).r,
//                          capturedImageTextureCbCr.sample(colorSampler, in.texCoord).rg, 1.0);
//
//    // Return converted RGB color
//    return ycbcrToRGBTransform * ycbcr;
//}

