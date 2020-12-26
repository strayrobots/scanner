//
//  CameraRenderer.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 12/20/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import Foundation
import Metal
import ARKit

class CameraRenderer {
    private var device: MTLDevice!
    private var rgbLayer: CAMetalLayer!
    private var depthLayer: CAMetalLayer!
    private var vertexBuffer: MTLBuffer!
    private var rgbPipelineState: MTLRenderPipelineState!
    private var depthPipelineState: MTLRenderPipelineState!
    private var commandQueue: MTLCommandQueue!
    private var rgbTextureY: MTLTexture!
    private var rgbTextureCbCr: MTLTexture!
    private var depthTexture: MTLTexture!
    private lazy var textureCache: CVMetalTextureCache = makeTextureCache()

    init(parentView: UIView) {
        initMetal(view: parentView)
    }

    func render(frame: ARFrame) {
        updateRGBTexture(frame: frame)
        updateDepthTexture(frame: frame)

        renderRGB()
        renderDepth()
    }

    private func renderRGB() {
        guard let drawable = rgbLayer.nextDrawable() else { return }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.pushDebugGroup("RGB")
        renderEncoder.setCullMode(.none)
        renderEncoder.label = "CustomCameraViewEncoder"
        renderEncoder.setRenderPipelineState(rgbPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentTexture(rgbTextureY, index: 0)
        renderEncoder.setFragmentTexture(rgbTextureCbCr, index: 1)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func renderDepth() {
        guard let drawable = depthLayer.nextDrawable() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.pushDebugGroup("Depth")
        renderEncoder.setCullMode(.none)
        renderEncoder.label = "DepthEncoder"
        renderEncoder.setRenderPipelineState(depthPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentTexture(depthTexture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func initMetal(view: UIView) {
        device = MTLCreateSystemDefaultDevice()
        rgbLayer = CAMetalLayer()
        rgbLayer.device = device
        rgbLayer.pixelFormat = .bgra8Unorm
        rgbLayer.framebufferOnly = true
        rgbLayer.frame = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: view.bounds.size.width * 1920.0/1440.0)
        view.layer.addSublayer(rgbLayer)

        depthLayer = CAMetalLayer()
        depthLayer.device = device
        depthLayer.framebufferOnly = true
        depthLayer.frame = CGRect(x: 0, y: 50, width: view.bounds.size.width, height: view.bounds.size.width * 1920.0/1440.0)
        view.layer.addSublayer(depthLayer)

        let dataSize = vertexData.count * MemoryLayout<Float>.size
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])

        let imagePlaneVertexDescriptor = MTLVertexDescriptor()
        // Vertices.
        imagePlaneVertexDescriptor.attributes[0].format = .float2
        imagePlaneVertexDescriptor.attributes[0].offset = 0
        imagePlaneVertexDescriptor.attributes[0].bufferIndex = 0

        // Texture coordinates.
        imagePlaneVertexDescriptor.attributes[1].format = .float2
        imagePlaneVertexDescriptor.attributes[1].offset = 8
        imagePlaneVertexDescriptor.attributes[1].bufferIndex = 0

        // Buffer layout.
        imagePlaneVertexDescriptor.layouts[0].stride = 16
        imagePlaneVertexDescriptor.layouts[0].stepRate = 1
        imagePlaneVertexDescriptor.layouts[0].stepFunction = .perVertex

        let defaultLibrary = device.makeDefaultLibrary()!

        let pipeline = MTLRenderPipelineDescriptor()
        pipeline.label = "CustomCameraView"
        let vertexFunction = defaultLibrary.makeFunction(name: "drawRectangle")
        pipeline.vertexFunction = vertexFunction
        pipeline.fragmentFunction = defaultLibrary.makeFunction(name: "displayTexture")
        pipeline.vertexDescriptor = imagePlaneVertexDescriptor
        pipeline.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline.sampleCount = 1

        let depthPipeline = MTLRenderPipelineDescriptor()
        depthPipeline.label = "DepthView"
        depthPipeline.vertexFunction = vertexFunction
        depthPipeline.fragmentFunction = defaultLibrary.makeFunction(name: "depthFragment")
        depthPipeline.vertexDescriptor = imagePlaneVertexDescriptor
        depthPipeline.colorAttachments[0].pixelFormat = depthLayer.pixelFormat
        depthPipeline.sampleCount = 1

        rgbPipelineState = try! device.makeRenderPipelineState(descriptor: pipeline)
        depthPipelineState = try! device.makeRenderPipelineState(descriptor: depthPipeline)

        commandQueue = device.makeCommandQueue()
    }

    private func updateRGBTexture(frame: ARFrame) {
        let colorImage = frame.capturedImage
        rgbTextureY = createTexture(fromPixelBuffer: colorImage, pixelFormat: .r8Unorm, planeIndex: 0)!
        rgbTextureCbCr = createTexture(fromPixelBuffer: colorImage, pixelFormat: .rg8Unorm, planeIndex: 1)!
    }

    private func updateDepthTexture(frame: ARFrame) {
        guard let sceneDepth = frame.sceneDepth else { return }
        let depthImage = sceneDepth.depthMap
        depthTexture = createTexture(fromPixelBuffer: depthImage, pixelFormat: .r32Float, planeIndex: 0)
    }

    private func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> MTLTexture? {
        var mtlTexture: MTLTexture? = nil
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        if status == kCVReturnSuccess {
            mtlTexture = CVMetalTextureGetTexture(texture!)
        }

        return mtlTexture
    }

    private func makeTextureCache() -> CVMetalTextureCache {
        var cache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        return cache
    }

}
