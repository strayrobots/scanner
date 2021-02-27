//
//  NPYArrayWrapper.h
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 2/27/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

#ifndef NPYArrayWrapper_h
#define NPYArrayWrapper_h
#include <Foundation/Foundation.h>

@interface NPYArrayWrapper : NSObject

- (instancetype) initWithArray:(uint16_t *)content width:(int)width height:(int)height;
- (instancetype) initWithDepth:(float *)content width:(int)width height:(int)height;

- (NSArray*) shape;

- (uint16_t*) contents;

- (NSData*) npyFileContents;

@end

#endif /* NPYArrayWrapper_h */
