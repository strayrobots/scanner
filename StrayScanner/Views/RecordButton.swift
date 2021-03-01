//
//  RecordButton.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 12/27/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable
class RecordButton : UIView {
    private let circleStroke: CGFloat = 5.0
    private let animationDuration = 0.1
    private var recording: Bool = false
    private var disk: CALayer!
    private var callback: Optional<(Bool) -> Void> = Optional.none

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
    }

    override func layoutSubviews() {
        setup()
    }

    required public init?(coder aCoder: NSCoder) {
        super.init(coder: aCoder)
        self.backgroundColor = UIColor.clear
    }

    func setCallback(callback: @escaping (Bool) -> Void) {
        self.callback = Optional.some(callback)
    }

    @objc func buttonPressed() {
        self.animateButton()
        self.recording = !self.recording
        self.callback?(self.recording)
    }

    private func setup() {
        drawInner()
        drawEdge()
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(buttonPressed)))
    }

    private func drawEdge() {
        let circleLayer = CAShapeLayer()
        let circleRadius: CGFloat = self.bounds.height * 0.5 - circleStroke;
        let x: CGFloat = self.bounds.size.width / 2
        let y: CGFloat = self.bounds.size.height / 2
        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: x, y: y), radius: circleRadius, startAngle: CGFloat(0), endAngle: CGFloat(Float.pi * 2.0), clockwise: false)
        circleLayer.path = path
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor(named: "DarkColor")!.cgColor
        circleLayer.lineWidth = circleStroke
        circleLayer.opacity = 1.0
        self.layer.addSublayer(circleLayer)
    }

    private func drawInner() {
        disk = CALayer()
        let diameter = self.bounds.height - circleStroke * 4.0
        let radius = diameter * 0.5
        let x: CGFloat = self.bounds.width * 0.5
        let y: CGFloat = self.bounds.height * 0.5
        let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        disk.backgroundColor = UIColor.red.cgColor
        disk.position.x = x
        disk.position.y = y
        disk.bounds = rect
        disk.cornerRadius = radius
        disk.opacity = 1.0
        disk.transform = CATransform3DIdentity
        self.layer.addSublayer(disk)
    }

    private func animateButton() {
        // Called before the flag is flipped.
        if self.recording {
            // Finished recording.
            self.animateToIdle()
        } else {
            self.animateToRecording()
        }
    }

    private func animateToRecording() {
        let squaringAnimation = CABasicAnimation(keyPath: "cornerRadius")
        squaringAnimation.fromValue = cornerRadius(recording: false)
        squaringAnimation.toValue = cornerRadius(recording: true)
        squaringAnimation.isRemovedOnCompletion = false
        squaringAnimation.fillMode = CAMediaTimingFillMode.forwards

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 0.5
        scaleAnimation.isRemovedOnCompletion = false
        scaleAnimation.fillMode = CAMediaTimingFillMode.forwards

        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [squaringAnimation, scaleAnimation]
        animationGroup.isRemovedOnCompletion = false
        animationGroup.fillMode = CAMediaTimingFillMode.forwards
        animationGroup.duration = animationDuration
        disk.add(animationGroup, forKey: "cornerRadius")
    }

    private func animateToIdle() {
        let roundingAnimation = CABasicAnimation(keyPath: "cornerRadius")
        roundingAnimation.fromValue = cornerRadius(recording: true)
        roundingAnimation.toValue = cornerRadius(recording: false)
        roundingAnimation.fillMode = CAMediaTimingFillMode.forwards
        roundingAnimation.isRemovedOnCompletion = false

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.5
        scaleAnimation.toValue = 1.0
        scaleAnimation.isRemovedOnCompletion = false
        scaleAnimation.fillMode = CAMediaTimingFillMode.forwards

        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [roundingAnimation, scaleAnimation]
        animationGroup.isRemovedOnCompletion = false
        animationGroup.fillMode = CAMediaTimingFillMode.forwards
        animationGroup.duration = animationDuration
        disk.add(animationGroup, forKey: "cornerRadius")
    }

    @objc override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        drawInner()
        drawEdge()
        self.backgroundColor = UIColor.clear
    }

    private func cornerRadius(recording: Bool) -> CGFloat {
        if recording {
            return 10.0
        } else {
            return (self.bounds.height - circleStroke * 4.0) * 0.5
        }
    }
}
