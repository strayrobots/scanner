//
//  NPYArrayWrapper.m
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 2/27/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "NPYArrayWrapper.h"
#import "cnpy.h"

@implementation NPYArrayWrapper {
    cnpy::NpyArray npyArray;
}

- (instancetype) initWithArray:(uint16_t *) content width:(int) width height:(int) height {
    self = [super init];
    if (self) {
        std::vector<size_t> shape = {size_t(height), size_t(width)};
        npyArray = cnpy::NpyArray(shape, 2, false);
        std::memcpy(self->npyArray.data_holder->data(), content, self->npyArray.num_bytes());
    }
    return self;
}

- (instancetype) initWithDepth:(Float32*) content width:(int) width height:(int) height {
    self = [super init];
    if (self) {
        std::vector<size_t> shape = {size_t(height), size_t(width)};
        npyArray = cnpy::NpyArray(shape, 2, false);
        
        uint16_t* data = npyArray.data<uint16_t>();
        for (int i=0; i < height; i++) {
            for (int j=0; j < width; j++) {
                int index = i * width + j;
                Float32 millimeters = std::round(content[index] * 1000.0f);
                data[index] = uint16_t(millimeters);
            }
        }
    }
    return self;
}

- (NSArray*) shape {
    NSMutableArray* array = [[NSMutableArray alloc] initWithCapacity:npyArray.shape.size()];
    for (int i=0; i < npyArray.shape.size(); i++) {
        NSNumber* dim = [NSNumber numberWithInt:int(npyArray.shape[i])];
        [array addObject:dim];
    }
    return array;
}

- (uint16_t*) contents {
    return npyArray.data<uint16_t>();
}

- (NSData*) npyFileContents {
    std::vector<char> header = cnpy::create_npy_header<uint16_t>(npyArray.shape);
    std::vector<size_t> shape = npyArray.shape;
    NSUInteger totalSize = header.size() + shape[0] * shape[1] * sizeof(uint16_t);
    NSMutableData* outData = [[NSMutableData alloc] initWithCapacity:totalSize];
    NSRange headerRange = NSMakeRange(0, header.size());
    [outData replaceBytesInRange:headerRange withBytes:header.data()];
    [outData replaceBytesInRange:NSMakeRange(header.size(), npyArray.num_bytes()) withBytes:npyArray.data_holder->data()];
    
    return outData;
}

@end
