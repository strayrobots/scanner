//
//  StrayScannerTests.swift
//  StrayScannerTests
//
//  Created by Kenneth Blomqvist on 2/27/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//

import XCTest

class StrayScannerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testNpyArrayCreate() throws {
        var frame: CVPixelBuffer? = nil
        let options = [ kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true ]
        let height: Int32 = 25
        let width: Int32 = 50
        CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height), kCVPixelFormatType_24RGB, options as CFDictionary, &frame)
        CVPixelBufferLockBaseAddress(frame!, CVPixelBufferLockFlags(rawValue: 1))
        let baseAddress = CVPixelBufferGetBaseAddress(frame!)!
        let frameData: UnsafeMutablePointer<UInt16> = baseAddress.assumingMemoryBound(to: UInt16.self)
        
        for i in 0...height {
            for j in 0...width {
                let index: Int = Int(i * width + j)
                frameData[index] = UInt16(index)
            }
        }
        let npyArray: NPYArrayWrapper = NPYArrayWrapper(array: frameData, width: width, height: height)!
        let shape = npyArray.shape()!
        
        XCTAssert(shape[0] as! Int == 25)
        XCTAssert(shape[1] as! Int == 50)
        
        let data = npyArray.contents()!
        XCTAssert(data[0] == 0)
        XCTAssert(data[1] == 1)
        XCTAssert(data[Int(width * height - 1)] == width * height - 1)

        CVPixelBufferUnlockBaseAddress(frame!, CVPixelBufferLockFlags(rawValue: 0))
    }
    
}
