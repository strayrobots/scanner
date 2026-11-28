//
//  PngWriter.m
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 2/15/22.
//  Copyright © 2022 Stray Robots. All rights reserved.
//

#import <Foundation/Foundation.h>
// No LODEPNG_NO_COMPILE_* defines here: they change the layout of lodepng::State,
// and lodepng.cpp is compiled without them, so the two would disagree.
#import "PngEncoder.h"
#import "lodepng.h"
#include <cmath>

@implementation PngEncoder {
    std::vector<unsigned char> png;
    std::vector<unsigned char> inputImage;
    int height;
    int width;
    int bitDepth;
}
- (instancetype) initWithDepth:(const float*) content width:(int) w height:(int) h {
    self = [super init];
    bitDepth = 16;
    width = w;
    height = h;
    inputImage.resize(width * height * 2);
    unsigned char* outData = inputImage.data();
    for (int y=0; y < height; y++) {
        for (int x=0; x < width; x++) {
            float value = content[y * width + x];
            uint16_t converted = uint16_t(std::round(value * 1000.0f));
            unsigned int index = (y * width + x) * 2;
            outData[index] = converted >> 8;
            outData[index+1] = converted & 0xFF;
        }
    }
    return self;
}

- (instancetype) initWithGray8:(const uint8_t*) content width:(int) w height:(int) h {
    self = [super init];
    bitDepth = 8;
    width = w;
    height = h;
    inputImage.assign(content, content + width * height);
    return self;
}

- (NSData*) fileContents {
    // Always write plain grayscale at the input bit depth (16 for depth, 8 for
    // confidence). With lodepng's default auto_convert it picks the smallest format
    // instead, e.g. 2-bit palette PNGs for confidence maps (only values 0-2) or
    // 1-bit PNGs for an all-zero depth map, which readers don't decode as gray values.
    lodepng::State state;
    state.info_raw.colortype = LCT_GREY;
    state.info_raw.bitdepth = bitDepth;
    state.info_png.color.colortype = LCT_GREY;
    state.info_png.color.bitdepth = bitDepth;
    state.encoder.auto_convert = 0;
    unsigned error = lodepng::encode(png, inputImage, width, height, state);
    if (error) {
        NSLog(@"PNG encoding failed: %s", lodepng_error_text(error));
        return nil;
    }
    NSData* outData = [[NSData alloc] initWithBytes:(void*)png.data() length:png.size()];
    return outData;
}


@end
