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
    private var updateLabelTimer: Timer?
    private var startedRecording: Date?
    @IBOutlet private var rgbView: MetalView!
    @IBOutlet private var depthView: MetalView!
    @IBOutlet private var recordButton: RecordButton!
    @IBOutlet private var timeLabel: UILabel!

    override func viewDidLoad() {
        self.renderer = CameraRenderer(rgbLayer: rgbView.layer, depthLayer: depthView.layer)

        depthView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))
        rgbView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))

        setViewProperties()
        session.delegate = self

        timer = CADisplayLink(target: self, selector: #selector(renderLoop))
        timer.add(to: RunLoop.main, forMode: .default)

        recordButton.setCallback {
            self.toggleRecording()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        session.pause();
    }

    override func viewWillAppear(_ animated: Bool) {
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        updateLabelTimer?.invalidate()
    }

    override func viewDidAppear(_ animated: Bool) {
        startSession()
    }

    private func startSession() {
        let arConfiguration = ARWorldTrackingConfiguration()
        if !ARWorldTrackingConfiguration.isSupported || !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            print("AR is not supported.")
        } else {
            arConfiguration.frameSemantics.insert(.sceneDepth)
            session.run(arConfiguration)
        }
    }

    private func toggleRecording() {
        if startedRecording == nil {
            startRecording()
        } else {
            stopRecording()
        }
    }

    private func startRecording() {
        startedRecording = Date()
        updateTime()
        updateLabelTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.updateTime()
        }
    }

    private func stopRecording() {
        startedRecording = nil
        updateLabelTimer?.invalidate()
        updateLabelTimer = nil
    }

    private func updateTime() {
        guard let started = self.startedRecording else { return }
        let seconds = Date().timeIntervalSince(started)
        let minutes: Int = Int(floor(seconds / 60).truncatingRemainder(dividingBy: 60))
        let hours: Int = Int(floor(seconds / 3600))
        let roundSeconds: Int = Int(floor(seconds.truncatingRemainder(dividingBy: 60)))
        self.timeLabel.text = String(format: "%02d:%02d:%02d", hours, minutes, roundSeconds)
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
        self.view.backgroundColor = UIColor(named: "DarkGrey")
    }
}
