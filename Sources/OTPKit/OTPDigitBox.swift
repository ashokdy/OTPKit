//
//  OTPDigitBox.swift
//  OTPKit
//
//  Copyright © 2026 SalesXRM. All rights reserved.
//

import UIKit

///One glossy digit box of the OTP entry row.
class OTPDigitBox: UIView {

    enum BoxState {
        case normal
        case success
        case failure
    }

    let digitLabel = UILabel()

    var theme = OTPTheme(){
        didSet{
            digitLabel.font = theme.boldFont(24)
            updateState()
        }
    }

    private let gradientLayer = CAGradientLayer()
    private let shineLayer = CAGradientLayer()

    var isActive = false{
        didSet{
            updateState()
        }
    }

    var state:BoxState = .normal{
        didSet{
            updateState()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup(){

        backgroundColor = .white
        layer.cornerRadius = 12
        layer.borderWidth = 1

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 3)

        //Base vertical gradient (white -> light gray)
        gradientLayer.colors = [UIColor.white.cgColor,
                                UIColor(red: 240/255.0, green: 240/255.0, blue: 240/255.0, alpha: 1).cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.cornerRadius = 12
        gradientLayer.masksToBounds = true
        layer.insertSublayer(gradientLayer, at: 0)

        //Glossy shine on the top half
        shineLayer.colors = [UIColor.white.withAlphaComponent(0.9).cgColor,
                             UIColor.white.withAlphaComponent(0.0).cgColor]
        shineLayer.startPoint = CGPoint(x: 0.5, y: 0)
        shineLayer.endPoint = CGPoint(x: 0.5, y: 1)
        shineLayer.cornerRadius = 12
        layer.insertSublayer(shineLayer, at: 1)

        digitLabel.font = theme.boldFont(24)
        digitLabel.textColor = theme.primaryTextColor
        digitLabel.textAlignment = .center
        digitLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(digitLabel)

        NSLayoutConstraint.activate([
            digitLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            digitLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateState()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        gradientLayer.frame = bounds
        shineLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height/2)
    }

    private func updateState(){

        switch state {

        case .normal:
            layer.borderColor = isActive
                ? theme.accentColor.cgColor
                : UIColor(red: 220/255.0, green: 220/255.0, blue: 220/255.0, alpha: 1).cgColor
            layer.borderWidth = isActive ? 1.5 : 1
            digitLabel.textColor = theme.primaryTextColor

        case .success:
            layer.borderColor = theme.successColor.cgColor
            layer.borderWidth = 1.5
            digitLabel.textColor = theme.successColor

        case .failure:
            layer.borderColor = theme.failureColor.cgColor
            layer.borderWidth = 1.5
            digitLabel.textColor = theme.failureColor
        }
    }
}
