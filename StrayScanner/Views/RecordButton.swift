//
//  RecordButton.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 12/27/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import Foundation
import UIKit

class RecordButton : UIView {
    private let circleStroke: CGFloat = 5.0
    private var recording: Bool = false

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
        setup()
    }

    required public init?(coder aCoder: NSCoder) {
        super.init(coder: aCoder)
        self.backgroundColor = UIColor.clear
        setup()
    }

    func setup() {
        drawInner()
        drawEdge()
    }

    func drawEdge() {
        let circleLayer = CAShapeLayer()
        let circleRadius: CGFloat = self.bounds.height * 0.5 - circleStroke;
        let x: CGFloat = self.bounds.size.width / 2
        let y: CGFloat = self.bounds.size.height / 2
        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: x, y: y), radius: circleRadius, startAngle: CGFloat(0), endAngle: CGFloat(Float.pi * 2.0), clockwise: false)
        circleLayer.path = path
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.white.cgColor
        circleLayer.lineWidth = circleStroke
        circleLayer.opacity = 1.0
        self.layer.addSublayer(circleLayer)
    }

    func drawInner() {
        let disk = CAShapeLayer()
        let diameter = self.bounds.height - circleStroke * 4.0
        let radius = diameter * 0.5
        let x: CGFloat = self.bounds.width * 0.5 - radius
        let y: CGFloat = self.bounds.height * 0.5 - radius
        let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
        let path = CGMutablePath()
        path.addEllipse(in: rect)
        disk.path = path
        disk.fillColor = UIColor.red.cgColor
        disk.opacity = 1.0
        self.layer.addSublayer(disk)
    }
}
