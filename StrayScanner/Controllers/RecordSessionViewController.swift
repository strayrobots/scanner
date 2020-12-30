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
import CoreData

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
    private var arConfiguration: ARConfiguration?
    private let session = ARSession()
    private var renderer: CameraRenderer?
    private var updateLabelTimer: Timer?
    private var startedRecording: Date?
    private var dataContext: NSManagedObjectContext!
    private var videoEncoder: VideoEncoder?
    private var videoId: UUID?
    @IBOutlet private var rgbView: MetalView!
    @IBOutlet private var depthView: MetalView!
    @IBOutlet private var recordButton: RecordButton!
    @IBOutlet private var timeLabel: UILabel!

    override func viewDidLoad() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        self.dataContext = appDelegate.persistentContainer.newBackgroundContext()
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
        let config = ARWorldTrackingConfiguration()
        arConfiguration = config
        if !ARWorldTrackingConfiguration.isSupported || !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            print("AR is not supported.")
        } else {
            config.frameSemantics.insert(.sceneDepth)
            session.run(config)
        }
    }

    private func toggleRecording() {
        if self.startedRecording == nil {
            startRecording()
        } else {
            stopRecording()
        }
    }

    private func startRecording() {
        self.startedRecording = Date()
        updateTime()
        updateLabelTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.updateTime()
        }
        videoId = UUID()
        let width = arConfiguration!.videoFormat.imageResolution.width
        let height = arConfiguration!.videoFormat.imageResolution.height
        videoEncoder = VideoEncoder(recordStart: self.startedRecording!, videoId: videoId!, width: width, height: height)
    }

    private func stopRecording() {
        if let started = startedRecording {
            let duration = Date().timeIntervalSince(started)
            let entity = NSEntityDescription.entity(forEntityName: "Recording", in: self.dataContext)!
            let recording: Recording = Recording(entity: entity, insertInto: self.dataContext)
            recording.id = videoId!
            recording.duration = duration
            recording.createdAt = started
            recording.name = "Placeholder"
            recording.rgbFilePath = videoEncoder?.filePath
            do {
                try self.dataContext.save()
            } catch let error as NSError {
                print("Could not save recording. \(error), \(error.userInfo)")
            }
            startedRecording = nil
            updateLabelTimer?.invalidate()
            updateLabelTimer = nil
        } else {
            print("Hasn't started recording. Something is wrong.")
        }
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
