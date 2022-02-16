//
//  PngWriter.m
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 2/15/22.
//  Copyright © 2022 Stray Robots. All rights reserved.
//

#import <Foundation/Foundation.h>
#define LODEPNG_NO_COMPILE_DECODER 1
#define LODEPNG_NO_COMPILE_DISK 1
#import "PngEncoder.h"
#import "lodepng.h"
#include <cmath>

@implementation PngEncoder {
    std::vector<unsigned char> png;
    std::vector<unsigned char> inputImage;
    int height;
    int width;
}
- (instancetype) initWithDepth:(float*) content width:(int) w height:(int) h {
    self = [super init];
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

- (NSData*) fileContents {
    lodepng::encode(png, inputImage, width, height, LCT_GREY, 16);
    NSData* outData = [[NSData alloc] initWithBytes:(void*)png.data() length:png.size()];
    return outData;
}


@end
