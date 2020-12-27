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
    -1.0, -1.0, 1.0, 1.0,
     1.0, -1.0, 1.0, 0.0,
    -1.0,  1.0, 0.0, 1.0,
     1.0,  1.0, 0.0, 0.0
]

let vertexIndices: [UInt16] = [
    0, 3, 1,
    0, 2, 3,
]

class MetalView : UIView {
    override class var layerClass: AnyClass {
        get {
            return CAMetalLayer.self
        }
    }
    override var layer: CAMetalLayer {
        return super.layer as! CAMetalLayer
    }
}

class RecordSessionViewController : UIViewController, ARSessionDelegate {
    private var timer: CADisplayLink!
    private let session = ARSession()
    private var renderer: CameraRenderer?
    private var rgbView: MetalView!
    private var depthView: MetalView!

    override func viewDidLoad() {
        rgbView = MetalView()
        let viewFrame = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: view.bounds.size.width * 1920.0/1440.0)
        rgbView.frame = viewFrame
        rgbView.isHidden = true
        view.addSubview(rgbView)

        depthView = MetalView()
        depthView.frame = viewFrame
        view.addSubview(depthView)

        self.renderer = CameraRenderer(rgbLayer: rgbView.layer, depthLayer: depthView.layer)

        depthView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))
        rgbView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))

        setViewProperties()
        session.delegate = self

        timer = CADisplayLink(target: self, selector: #selector(renderLoop))
        timer.add(to: RunLoop.main, forMode: .default)

        let arConfiguration = ARWorldTrackingConfiguration()
        if !ARWorldTrackingConfiguration.isSupported || !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            print("AR is not supported.")
        } else {
            arConfiguration.frameSemantics.insert(.sceneDepth)
            session.run(arConfiguration)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        session.pause();
    }

    @objc func viewTapped() {
        switch renderer!.renderMode {
            case .depth:
                renderer!.renderMode = RenderMode.rgb
                rgbView.isHidden = false
                depthView.isHidden = true
            case .rgb:
                renderer!.renderMode = RenderMode.depth
                depthView.isHidden = false
                rgbView.isHidden = true
        }
    }

    @objc func renderLoop() {
        autoreleasepool {
            guard let frame = session.currentFrame else { return }
            self.renderer!.render(frame: frame)
        }
    }
    private func setViewProperties() {
        view.backgroundColor = UIColor.black
        view.setNeedsDisplay()
    }
}
