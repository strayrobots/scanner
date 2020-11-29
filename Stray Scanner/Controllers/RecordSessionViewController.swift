//
//  RecordSessionViewController.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/28/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import Foundation
import UIKit
import Metal
import ARKit

let vertexData: [Float] = [
    -1.0, -1.0, 0.0,
    -1.0,  1.0, 0.0,
     1.0, -1.0, 0.0,
     1.0,  1.0, 0.0,
]

let vertexIndices: [UInt16] = [
    0, 3, 1,
    0, 2, 3,
]

class RecordSessionViewController : UIViewController, ARSessionDelegate {
    var device: MTLDevice!
    var metalLayer: CAMetalLayer!
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var timer: CADisplayLink!
    var textureY: MTLTexture!
    var textureCbCr: MTLTexture!
    let session = ARSession()

    override func viewDidLoad() {
        session.delegate = self
        device = MTLCreateSystemDefaultDevice()
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame
        view.layer.addSublayer(metalLayer)

        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
        let indicesSize = vertexData.count * MemoryLayout.size(ofValue: vertexIndices[0])
        indexBuffer = device.makeBuffer(bytes: vertexIndices, length: indicesSize, options: [])

        let defaultLibary = device.makeDefaultLibrary()!

        let pipeline = MTLRenderPipelineDescriptor()
        pipeline.vertexFunction = defaultLibary.makeFunction(name: "drawRectangle")
        pipeline.fragmentFunction = defaultLibary.makeFunction(name: "constantColor")
        pipeline.colorAttachments[0].pixelFormat = .bgra8Unorm

        pipelineState = try! device.makeRenderPipelineState(descriptor: pipeline)

        commandQueue = device.makeCommandQueue()

        timer = CADisplayLink(target: self, selector: #selector(renderLoop))
        timer.add(to: RunLoop.main, forMode: .default)

        //let arConfiguration = ARWorldTrackingConfiguration()
        //session.run(arConfiguration)
    }

    func render() {
        //guard let frame = session.currentFrame else { return }
        //updateTexture(frame: frame)

        guard let drawable = metalLayer.nextDrawable() else { return }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.2,
            green: 0.2,
            blue: 0.2,
            alpha: 1.0)

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 6, indexType: MTLIndexType.uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    @objc func renderLoop() {
        autoreleasepool {
            self.render()
        }
    }
    
    private func updateTexture(frame: ARFrame) {
        //let colorImage = frame.capturedImage
        //textureY = createTexture(fromPixelBuffer: colorImage, pixelFormat: .r8Unorm, planeIndex: 0)!
        //textureCbCr = createTexture(fromPixelBuffer: colorImage, pixelFormat: .rg8Unorm, planeIndex: 1)!
    }

    //private func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> MTLTexture? {
    //    var mtlTexture: MTLTexture? = nil
    //    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
    //    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

    //    var texture: CVMetalTexture? = nil
    //    let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
    //    if status == kCVReturnSuccess {
    //        mtlTexture = CVMetalTextureGetTexture(texture!)
    //    }

    //    return mtlTexture
    //}
}
