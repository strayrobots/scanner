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
import CoreMotion

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
    private var unsupported: Bool = false
    private var arConfiguration: ARWorldTrackingConfiguration?
    private let session = ARSession()
    private let motionManager = CMMotionManager()
    private var renderer: CameraRenderer?
    private var updateLabelTimer: Timer?
    private var startedRecording: Date?
    private var dataContext: NSManagedObjectContext!
    private var datasetEncoder: DatasetEncoder?
    private let imuOperationQueue = OperationQueue()
    @IBOutlet private var rgbView: MetalView!
    @IBOutlet private var depthView: MetalView!
    @IBOutlet private var recordButton: RecordButton!
    @IBOutlet private var timeLabel: UILabel!
    var dismissFunction: Optional<() -> Void> = Optional.none
    
    func setDismissFunction(_ fn: Optional<() -> Void>) {
        self.dismissFunction = fn
    }

    override func viewDidLoad() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        self.dataContext = appDelegate.persistentContainer.newBackgroundContext()
        self.renderer = CameraRenderer(rgbLayer: rgbView.layer, depthLayer: depthView.layer)

        depthView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))
        rgbView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))
        
        setViewProperties()
        session.delegate = self

        recordButton.setCallback { (recording: Bool) in
            self.toggleRecording(recording)
        }
        
        imuOperationQueue.qualityOfService = .userInitiated
    }

    override func viewDidDisappear(_ animated: Bool) {
        session.pause();
    }

    override func viewWillDisappear(_ animated: Bool) {
        updateLabelTimer?.invalidate()
        datasetEncoder = nil
    }

    override func viewDidAppear(_ animated: Bool) {
        startSession()
    }

    private func startSession() {
        let config = ARWorldTrackingConfiguration()
        arConfiguration = config
        if !ARWorldTrackingConfiguration.isSupported || !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            print("AR is not supported.")
            unsupported = true
        } else {
            config.frameSemantics.insert(.sceneDepth)
            session.run(config)
        }
    }
    
    private func startAccelerometer() {
        if self.motionManager.isAccelerometerAvailable {
            self.motionManager.deviceMotionUpdateInterval = 1.0 / 1200.0
            self.motionManager.startDeviceMotionUpdates(to: imuOperationQueue, withHandler: motionHandler)
        }
    }
    
    private func stopAccelerometer() {
        self.motionManager.stopDeviceMotionUpdates()
    }
    
    private func motionHandler(motion: CMDeviceMotion?, error: Error?) -> Void {
        if motion != nil && datasetEncoder != nil {
            datasetEncoder!.addIMU(motion: motion!)
        }
    }

    private func toggleRecording(_ recording: Bool) {
        if unsupported {
            showUnsupportedAlert()
            return
        }
        if recording && self.startedRecording == nil {
            startRecording()
        } else if self.startedRecording != nil && !recording {
            stopRecording()
        } else {
            print("This should not happen. We are either not recording and want to stop, or we are recording and want to start.")
        }
    }

    private func startRecording() {
        self.startedRecording = Date()
        updateTime()
        updateLabelTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.updateTime()
        }
        datasetEncoder = DatasetEncoder(arConfiguration: arConfiguration!)
        startAccelerometer()
    }

    private func stopRecording() {
        guard let started = self.startedRecording else {
            print("Hasn't started recording. Something is wrong.")
            return
        }
        startedRecording = nil
        updateLabelTimer?.invalidate()
        updateLabelTimer = nil
        stopAccelerometer()
        datasetEncoder?.wrapUp()
        if let encoder = datasetEncoder {
            switch encoder.status {
                case .allGood:
                    saveRecording(started, encoder)
                case .videoEncodingError:
                    showError()
                case .directoryCreationError:
                    showError()
            }
        } else {
            print("No dataset encoder. Something is wrong.")
        }
        self.dismissFunction?()
    }

    private func saveRecording(_ started: Date, _ encoder: DatasetEncoder) {
        let sessionCount = countSessions()
        
        let duration = Date().timeIntervalSince(started)
        let entity = NSEntityDescription.entity(forEntityName: "Recording", in: self.dataContext)!
        let recording: Recording = Recording(entity: entity, insertInto: self.dataContext)
        recording.setValue(datasetEncoder!.id, forKey: "id")
        recording.setValue(duration, forKey: "duration")
        recording.setValue(started, forKey: "createdAt")
        recording.setValue("Recording \(sessionCount)", forKey: "name")
        recording.setValue(datasetEncoder!.rgbFilePath.relativeString, forKey: "rgbFilePath")
        recording.setValue(datasetEncoder!.depthFilePath.relativeString, forKey: "depthFilePath")
        do {
            try self.dataContext.save()
        } catch let error as NSError {
            print("Could not save recording. \(error), \(error.userInfo)")
        }
    }

    private func showError() {
        let controller = UIAlertController(title: "Error",
            message: "Something went wrong when encoding video. This should not have happened. You might want to file a bug report.",
            preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default Action"), style: .default, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        self.present(controller, animated: true, completion: nil)
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

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        self.renderer!.render(frame: frame)
        if startedRecording != nil {
            if let encoder = datasetEncoder {
                encoder.add(frame: frame)
            } else {
                print("There is no video encoder. That can't be good.")
            }
        }
    }

    private func setViewProperties() {
        self.view.backgroundColor = UIColor(named: "BackgroundColor")
    }
    
    private func showUnsupportedAlert() {
        let alert = UIAlertController(title: "Unsupported device", message: "This device doesn't seem to have the required level of ARKit support.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.dismissFunction?()
        }))
        self.present(alert, animated: true)
    }
    
    private func countSessions() -> Int {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return 0 }
        let request = NSFetchRequest<NSManagedObject>(entityName: "Recording")
        do {
            let fetched: [NSManagedObject] = try appDelegate.persistentContainer.viewContext.fetch(request)
            return fetched.count
        } catch let error {
            print("Could not fetch sessions for counting. \(error.localizedDescription)")
        }
        return 0
    }
}
