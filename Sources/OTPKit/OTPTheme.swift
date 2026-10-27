//
//  OTPTheme.swift
//  OTPKit
//
//  Copyright © 2026 SalesXRM. All rights reserved.
//

import UIKit

///Look & feel of the OTP views. The host app injects its own colors/fonts;
///every property has a sensible system default so the kit also works standalone.
public struct OTPTheme {

    ///Active digit box border, resend button, seal icon accents
    public var accentColor: UIColor

    ///Digit boxes + seal when the code matches
    public var successColor: UIColor

    ///Digit boxes + expiry text when the code is wrong / expired
    public var failureColor: UIColor

    ///Entered digits, titles
    public var primaryTextColor: UIColor

    ///Subtitles, countdowns, disabled resend
    public var secondaryTextColor: UIColor

    ///Provider so the host can pass its custom font family
    public var boldFont: (_ size: CGFloat) -> UIFont
    public var regularFont: (_ size: CGFloat) -> UIFont

    public init(accentColor: UIColor = .systemBlue,
                successColor: UIColor = .systemGreen,
                failureColor: UIColor = .systemRed,
                primaryTextColor: UIColor = .label,
                secondaryTextColor: UIColor = .secondaryLabel,
                boldFont: @escaping (_ size: CGFloat) -> UIFont = { UIFont.boldSystemFont(ofSize: $0) },
                regularFont: @escaping (_ size: CGFloat) -> UIFont = { UIFont.systemFont(ofSize: $0) }) {

        self.accentColor = accentColor
        self.successColor = successColor
        self.failureColor = failureColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.boldFont = boldFont
        self.regularFont = regularFont
    }
}
