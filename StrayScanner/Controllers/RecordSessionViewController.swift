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

// Frame rates the user can pick from. Only the ones that evenly divide the
// active video format's native frame rate are offered (60 fps -> 60/30/15/5/1,
// 30 fps -> 30/15/5/1), since frames are kept by skipping every n-th frame.
let CandidateFpsSettings: [Int] = [60, 30, 15, 5, 1]
let FpsUserDefaultsKey: String = "FPSValue"
let LegacyFpsIndexUserDefaultsKey: String = "FPS" // Index into the old [60, 30, 15, 5, 1] list.
let Use4KUserDefaultsKey: String = "Use4KVideo"
// ARKit's sceneDepth map is 256x192 (4:3) for every video format, including 4K.
let DepthMapAspectRatio: CGFloat = 192.0 / 256.0 // Portrait width:height.

enum VideoResolutionSetting {
    case standard // ARKit's default format, 1920x1440 binned from the sensor.
    case uhd4K    // ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution, 3840x2160.
}

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
    // The IMU callbacks' reference to the encoder. Only touched on imuOperationQueue,
    // or on the main thread after IMU updates are stopped and the queue drained.
    private var imuDatasetEncoder: DatasetEncoder?
    private let imuOperationQueue = OperationQueue()
    // The rate the user picked, persisted in UserDefaults. It may not be available
    // for the current video format (e.g. 60 fps in 4K), see chosenFps.
    private var preferredFps: Int = 60
    private var resolutionSetting: VideoResolutionSetting = .standard
    private let standardVideoFormat: ARConfiguration.VideoFormat = ARWorldTrackingConfiguration().videoFormat
    private let resolutionButton = UIButton(type: .system)
    private var previewAspectConstraints: [NSLayoutConstraint] = []
    @IBOutlet private var rgbView: MetalView!
    @IBOutlet private var depthView: MetalView!
    @IBOutlet private var recordButton: RecordButton!
    @IBOutlet private var timeLabel: UILabel!
    @IBOutlet weak var fpsButton: UIButton!
    var dismissFunction: Optional<() -> Void> = Optional.none
    
    func setDismissFunction(_ fn: Optional<() -> Void>) {
        self.dismissFunction = fn
    }
    override func viewWillAppear(_ animated: Bool) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: FpsUserDefaultsKey) != nil {
            preferredFps = defaults.integer(forKey: FpsUserDefaultsKey)
        } else {
            let legacyIndex = defaults.integer(forKey: LegacyFpsIndexUserDefaultsKey)
            preferredFps = CandidateFpsSettings.indices.contains(legacyIndex) ? CandidateFpsSettings[legacyIndex] : 60
        }
        if defaults.bool(forKey: Use4KUserDefaultsKey) && fourKVideoFormat != nil {
            resolutionSetting = .uhd4K
        } else {
            resolutionSetting = .standard
        }
        updateResolutionSetting()
        updateFpsSetting()
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
        fpsButton.layer.masksToBounds = true
        fpsButton.layer.cornerRadius = 12.0
        setupResolutionButton()
        previewAspectConstraints = [rgbView, depthView].compactMap { view in
            view.constraints.first { $0.firstAttribute == .width && $0.secondAttribute == .height }
        }

        imuOperationQueue.qualityOfService = .userInitiated
        // Accelerometer and gyro callbacks share state in DatasetEncoder, so run them one at a time.
        imuOperationQueue.maxConcurrentOperationCount = 1
    }

    override func viewDidDisappear(_ animated: Bool) {
        session.pause();
    }

    override func viewWillDisappear(_ animated: Bool) {
        // Let IMU callbacks already queued finish before releasing the encoder.
        stopRawIMU()
        imuOperationQueue.waitUntilAllOperationsAreFinished()
        imuDatasetEncoder = nil
        updateLabelTimer?.invalidate()
        datasetEncoder = nil
    }

    override func viewDidAppear(_ animated: Bool) {
        startSession()
        // Start the IMU now so it's already running when record is pressed. Samples
        // are discarded until a recording starts (imuDatasetEncoder is nil until then).
        startRawIMU()
    }

    private func startSession() {
        let config = ARWorldTrackingConfiguration()
        arConfiguration = config
        if !ARWorldTrackingConfiguration.isSupported || !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            print("AR is not supported.")
            unsupported = true
        } else {
            config.frameSemantics.insert(.sceneDepth)
            config.videoFormat = activeVideoFormat
            print("Running ARKit with video format \(describe(config.videoFormat)).")
            session.run(config)
            // Spin up the hardware video encoder for this resolution now, so the
            // first frames of a recording don't stall while it initializes.
            VideoEncoder.warmUp(width: config.videoFormat.imageResolution.width,
                                height: config.videoFormat.imageResolution.height)
        }
    }

    // nil if the device can't do 4K with world tracking (needs iPhone 11 or newer).
    private var fourKVideoFormat: ARConfiguration.VideoFormat? {
        return ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution
    }

    private var activeVideoFormat: ARConfiguration.VideoFormat {
        switch resolutionSetting {
            case .standard:
                return standardVideoFormat
            case .uhd4K:
                return fourKVideoFormat ?? standardVideoFormat
        }
    }

    private var availableFpsSettings: [Int] {
        let nativeFps = activeVideoFormat.framesPerSecond
        return CandidateFpsSettings.filter { $0 <= nativeFps && nativeFps % $0 == 0 }
    }

    private func describe(_ format: ARConfiguration.VideoFormat) -> String {
        return "\(Int(format.imageResolution.width))x\(Int(format.imageResolution.height)) @ \(format.framesPerSecond) fps"
    }
    
    private func startRawIMU() {
        if motionManager.isAccelerometerActive || motionManager.isGyroActive { return }
        if self.motionManager.isAccelerometerAvailable {
            self.motionManager.accelerometerUpdateInterval = 1.0 / 1200.0 // Set update rate
            self.motionManager.startAccelerometerUpdates(to: imuOperationQueue) { (data, error) in
                guard let data = data else {
                    if let error = error {
                        print("Error retrieving accelerometer data: \(error.localizedDescription)")
                    }
                    return
                }
                self.imuDatasetEncoder?.addRawAccelerometer(data: data)
            }
        } else {
            print("Accelerometer not available on this device.")
        }

        if self.motionManager.isGyroAvailable {
            self.motionManager.gyroUpdateInterval = 1.0 / 1200.0 // Set update rate
            self.motionManager.startGyroUpdates(to: imuOperationQueue) { (data, error) in
                guard let data = data else {
                    if let error = error {
                        print("Error retrieving gyroscope data: \(error.localizedDescription)")
                    }
                    return
                }
                self.imuDatasetEncoder?.addRawGyroscope(data: data)
            }
        } else {
            print("Gyroscope not available on this device.")
        }
    }

    private func stopRawIMU() {
        if self.motionManager.isAccelerometerActive {
            self.motionManager.stopAccelerometerUpdates()
            print("Stopped accelerometer updates.")
        }
        if self.motionManager.isGyroActive {
            self.motionManager.stopGyroUpdates()
            print("Stopped gyroscope updates.")
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
        let fpsDivider = arConfiguration!.videoFormat.framesPerSecond / chosenFps
        // Same clock as ARFrame.timestamp and CMLogItem.timestamp. Frames reach us
        // ~100 ms after capture, so anything captured before this moment is skipped.
        let pressedAt = CACurrentMediaTime()
        let encoder = DatasetEncoder(arConfiguration: arConfiguration!, fpsDivider: fpsDivider, startTime: pressedAt)
        datasetEncoder = encoder
        // The IMU may already be running, so hand the encoder over on its queue.
        imuOperationQueue.addOperation {
            self.imuDatasetEncoder = encoder
        }
        resolutionButton.isEnabled = false
        startRawIMU() // No-op if it's already running since the view appeared.
    }

    private func stopRecording() {
        guard let started = self.startedRecording else {
            print("Hasn't started recording. Something is wrong.")
            return
        }
        startedRecording = nil
        resolutionButton.isEnabled = true
        updateLabelTimer?.invalidate()
        updateLabelTimer = nil
        // Stop IMU updates, and let callbacks already queued finish before the IMU file is closed.
        stopRawIMU()
        imuOperationQueue.waitUntilAllOperationsAreFinished()
        imuDatasetEncoder = nil
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
    
    @IBAction func fpsButtonTapped() {
        let options = availableFpsSettings
        let index = options.firstIndex(of: chosenFps) ?? -1
        preferredFps = options[(index + 1) % options.count]
        updateFpsSetting()
        UserDefaults.standard.set(preferredFps, forKey: FpsUserDefaultsKey)
    }

    @objc func resolutionButtonTapped() {
        guard startedRecording == nil, fourKVideoFormat != nil else { return }
        resolutionSetting = resolutionSetting == .standard ? .uhd4K : .standard
        UserDefaults.standard.set(resolutionSetting == .uhd4K, forKey: Use4KUserDefaultsKey)
        updateResolutionSetting()
        updateFpsSetting()
        if !unsupported && arConfiguration != nil {
            // The video format can only change by re-running the session.
            startSession()
        }
    }

    private func setupResolutionButton() {
        resolutionButton.translatesAutoresizingMaskIntoConstraints = false
        // Match the look of the FPS button from the XIB.
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = fpsButton.backgroundColor
        configuration.baseForegroundColor = fpsButton.titleColor(for: .normal)
        configuration.background.cornerRadius = 12.0
        configuration.cornerStyle = .fixed
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        let font = fpsButton.titleLabel?.font
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = font
            return attributes
        }
        resolutionButton.configuration = configuration
        resolutionButton.addTarget(self, action: #selector(resolutionButtonTapped), for: .touchUpInside)
        resolutionButton.accessibilityLabel = "Video resolution"
        view.addSubview(resolutionButton)
        NSLayoutConstraint.activate([
            resolutionButton.leadingAnchor.constraint(equalTo: fpsButton.trailingAnchor, constant: 8),
            resolutionButton.centerYAnchor.constraint(equalTo: fpsButton.centerYAnchor),
            resolutionButton.heightAnchor.constraint(equalTo: fpsButton.heightAnchor)
        ])
        // Only offer the toggle on devices where ARKit has a 4K format.
        resolutionButton.isHidden = fourKVideoFormat == nil
    }

    private func updateResolutionSetting() {
        resolutionButton.configuration?.title = resolutionSetting == .uhd4K ? "4K" : "HD"
        resolutionButton.accessibilityValue = describe(activeVideoFormat)
        updatePreviewAspectRatio()
    }

    // The preview is shown in portrait, so its width:height is the image's height:width
    // (1440:1920 for the standard format, 2160:3840 for 4K). The depth map stays 4:3
    // in every format, so the depth view keeps that aspect ratio.
    private func updatePreviewAspectRatio() {
        let resolution = activeVideoFormat.imageResolution
        let aspectRatios: [(UIView, CGFloat)] = [
            (rgbView, resolution.height / resolution.width),
            (depthView, DepthMapAspectRatio)
        ]
        NSLayoutConstraint.deactivate(previewAspectConstraints)
        previewAspectConstraints = aspectRatios.map { (view, aspectRatio) in
            view.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: aspectRatio)
        }
        NSLayoutConstraint.activate(previewAspectConstraints)
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

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("ARSession failed with video format \(describe(activeVideoFormat)): \(error.localizedDescription)")
    }

    private func setViewProperties() {
        self.view.backgroundColor = UIColor(named: "BackgroundColor")
    }
    
    // The rate actually used for the current video format. If the preferred rate isn't
    // available (e.g. 60 fps was chosen and 4K runs at 30 fps), fall back to the highest
    // rate at or below it. The preference is kept, so switching back to HD restores it.
    private var chosenFps: Int {
        let options = availableFpsSettings
        if options.contains(preferredFps) {
            return preferredFps
        }
        return options.first { $0 <= preferredFps } ?? options.last!
    }

    private func updateFpsSetting() {
        let buttonLabel: String = "\(chosenFps) fps"
        fpsButton.setTitle(buttonLabel, for: UIControl.State.normal)
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
