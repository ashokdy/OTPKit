//
//  OTPPopupViewController.swift
//  OTPKit
//
//  Copyright © 2026 SalesXRM. All rights reserved.
//

import UIKit

///Result of a resend request: the freshly issued code and its expiry.
public struct OTPResendResult {

    public var code:String
    public var expiryDate:Date?

    public init(code:String, expiryDate:Date? = nil){
        self.code = code
        self.expiryDate = expiryDate
    }
}

///Card-style OTP popup: seal + title + destination line + `OTPEntryView` +
///resend cooldown + expiry countdown. Present over full screen:
///
///    let vc = OTPPopupViewController()
///    vc.theme = ...                 //host colors/fonts
///    vc.expectedOTP = "123456"      //code returned by the send service
///    vc.numberOfDigits = 6
///    vc.destinationText = "user@host.com"
///    vc.expiryDate = ...
///    vc.onResend = { completion in ... completion(OTPResendResult(...)) }
///    vc.onCompletion = { verified in ... }
///    vc.modalPresentationStyle = .overFullScreen
///    vc.modalTransitionStyle = .crossDissolve
///    present(vc, animated: true)
public class OTPPopupViewController: UIViewController {

    //MARK: - Configuration

    public var theme = OTPTheme()

    public var numberOfDigits = 6
    public var expectedOTP = ""
    public var destinationText = ""
    public var expiryDate:Date? = nil

    public var titleText = "Verification Code"

    ///nil = default "Enter the N-digit code sent to\n<destination>"
    public var subtitleText:String? = nil

    public var resendCooldown = 30

    ///Called after dismissal. true only when the entered code matched.
    public var onCompletion:((_ verified:Bool)->Void)? = nil

    ///Host sends a new code and hands back the fresh OTPResendResult (nil on failure).
    ///When nil, the Resend button is hidden.
    public var onResend:((_ completion:@escaping (OTPResendResult?)->Void)->Void)? = nil

    //MARK: - Local Variables

    private var resendTimer:Timer? = nil
    private var resendSecondsLeft = 0
    private var expiryTimer:Timer? = nil
    private var isVerified = false

    //MARK: - UI

    private let cardView = UIView()
    private let cardGradientLayer = CAGradientLayer()
    private let sealImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let entryView = OTPEntryView()
    private let resendButton = UIButton(type: .system)
    private let expiryLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    private var cardCenterYConstraint:NSLayoutConstraint? = nil

    //MARK: - View LifeCycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black.withAlphaComponent(0.45)

        setupCard()
        setupContent()
        startResendCooldown()
        startExpiryCountdown()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        entryView.beginEntry()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        cardGradientLayer.frame = cardView.bounds
    }

    deinit {
        resendTimer?.invalidate()
        expiryTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    //MARK: - Setup

    private func setupCard(){

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 24
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.25
        cardView.layer.shadowRadius = 20
        cardView.layer.shadowOffset = CGSize(width: 0, height: 10)

        cardGradientLayer.colors = [UIColor.white.cgColor,
                                    UIColor(red: 248/255.0, green: 248/255.0, blue: 248/255.0, alpha: 1).cgColor]
        cardGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        cardGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        cardGradientLayer.cornerRadius = 24
        cardGradientLayer.masksToBounds = true
        cardView.layer.insertSublayer(cardGradientLayer, at: 0)

        view.addSubview(cardView)

        let centerY = cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60)
        cardCenterYConstraint = centerY

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerY,
            cardView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 360)
        ])

        let width = cardView.widthAnchor.constraint(equalToConstant: 360)
        width.priority = .defaultHigh
        width.isActive = true
    }

    private func setupContent(){

        //Close (X)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        if let image = UIImage(systemName: "xmark"){
            closeButton.setImage(image, for: .normal)
        }
        else{
            closeButton.setTitle("✕", for: .normal)
        }
        closeButton.tintColor = theme.secondaryTextColor
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        cardView.addSubview(closeButton)

        //Verified seal icon
        sealImageView.translatesAutoresizingMaskIntoConstraints = false
        sealImageView.image = UIImage(systemName: "checkmark.seal.fill")
        sealImageView.tintColor = theme.successColor
        sealImageView.contentMode = .scaleAspectFit
        cardView.addSubview(sealImageView)

        //Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = titleText
        titleLabel.font = theme.boldFont(18)
        titleLabel.textColor = theme.primaryTextColor
        titleLabel.textAlignment = .center
        cardView.addSubview(titleLabel)

        //Subtitle
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = subtitleText ?? "Enter the \(numberOfDigits)-digit code sent to\n\(destinationText)"
        subtitleLabel.font = theme.regularFont(13)
        subtitleLabel.textColor = theme.secondaryTextColor
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        cardView.addSubview(subtitleLabel)

        //Digit boxes
        entryView.translatesAutoresizingMaskIntoConstraints = false
        entryView.numberOfDigits = numberOfDigits
        entryView.theme = theme

        entryView.onCodeEntered = { [weak self] (entered) in
            self?.validateOTP(entered: entered)
        }

        cardView.addSubview(entryView)

        //Resend
        resendButton.translatesAutoresizingMaskIntoConstraints = false
        resendButton.titleLabel?.font = theme.boldFont(13)
        resendButton.setTitleColor(theme.accentColor, for: .normal)
        resendButton.setTitleColor(theme.secondaryTextColor, for: .disabled)
        resendButton.addTarget(self, action: #selector(resendTapped), for: .touchUpInside)
        resendButton.isHidden = (onResend == nil)
        cardView.addSubview(resendButton)

        //OTP expiry countdown
        expiryLabel.translatesAutoresizingMaskIntoConstraints = false
        expiryLabel.font = theme.regularFont(12)
        expiryLabel.textColor = theme.secondaryTextColor
        expiryLabel.textAlignment = .center
        expiryLabel.numberOfLines = 0
        cardView.addSubview(expiryLabel)

        NSLayoutConstraint.activate([

            closeButton.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            sealImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            sealImageView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            sealImageView.widthAnchor.constraint(equalToConstant: 48),
            sealImageView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.topAnchor.constraint(equalTo: sealImageView.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            entryView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            entryView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            entryView.leadingAnchor.constraint(greaterThanOrEqualTo: cardView.leadingAnchor, constant: 12),
            entryView.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -12),

            resendButton.topAnchor.constraint(equalTo: entryView.bottomAnchor, constant: 20),
            resendButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            expiryLabel.topAnchor.constraint(equalTo: resendButton.bottomAnchor, constant: 6),
            expiryLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            expiryLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            expiryLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    //MARK: - IBAction Methods

    @objc func closeTapped(){

        entryView.endEntry()

        dismiss(animated: true) { [weak self] in
            self?.onCompletion?(self?.isVerified ?? false)
        }
    }

    @objc func resendTapped(){

        guard let onResend = onResend else{
            return
        }

        resendButton.isEnabled = false
        setResendTitle("Sending...", for: .disabled)

        onResend { [weak self] (result) in

            guard let self = self else { return }

            if let result = result{

                self.expectedOTP = result.code
                self.expiryDate = result.expiryDate
                self.entryView.reset()
                self.startExpiryCountdown()
            }
            else{
                self.expiryTimer?.invalidate()
                self.expiryLabel.text = "Unable to resend the code. Please try again."
                self.expiryLabel.textColor = self.theme.failureColor
            }

            self.startResendCooldown()
        }
    }

    //MARK: - Custom Methods

    ///Matches the entered code against the expected one
    private func validateOTP(entered:String){

        if entered == expectedOTP{
            handleVerified()
        }
        else{
            handleFailed()
        }
    }

    private func handleVerified(){

        isVerified = true

        entryView.showSuccess()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in

            self?.dismiss(animated: true) {
                self?.onCompletion?(true)
            }
        }
    }

    private func handleFailed(){

        entryView.showFailure()

        shakeCard()
    }

    private func shakeCard(){

        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-12, 12, -9, 9, -5, 5, 0]
        cardView.layer.add(animation, forKey: "shake")
    }

    ///Updates the button title without UIButton's implicit crossfade so the
    ///countdown doesn't blink every second.
    private func setResendTitle(_ title:String, for state:UIControl.State){

        UIView.performWithoutAnimation {
            resendButton.setTitle(title, for: state)
            resendButton.layoutIfNeeded()
        }
    }

    private func startResendCooldown(){

        guard onResend != nil else { return }

        resendTimer?.invalidate()

        resendSecondsLeft = resendCooldown
        resendButton.isEnabled = false
        setResendTitle("Resend code in \(resendSecondsLeft)s", for: .disabled)

        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] (timer) in

            guard let self = self else{
                timer.invalidate()
                return
            }

            self.resendSecondsLeft -= 1

            if self.resendSecondsLeft <= 0{

                timer.invalidate()

                self.resendButton.isEnabled = true
                self.setResendTitle("Resend Code", for: .normal)
            }
            else{
                self.setResendTitle("Resend code in \(self.resendSecondsLeft)s", for: .disabled)
            }
        }
    }

    private func startExpiryCountdown(){

        expiryTimer?.invalidate()

        guard expiryDate != nil else{
            expiryLabel.text = nil
            return
        }

        updateExpiryLabel()

        expiryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] (timer) in

            guard let self = self else{
                timer.invalidate()
                return
            }

            self.updateExpiryLabel()
        }
    }

    private func updateExpiryLabel(){

        guard let expiryDate = expiryDate else{
            expiryLabel.text = nil
            return
        }

        let remaining = Int(expiryDate.timeIntervalSinceNow)

        if remaining <= 0{

            expiryTimer?.invalidate()
            expiryLabel.text = "Password expired. Tap Resend Code to get a new one."
            expiryLabel.textColor = theme.failureColor
        }
        else{
            expiryLabel.text = "Password will expire in \(remaining)s"
            expiryLabel.textColor = theme.secondaryTextColor
        }
    }

    @objc func keyboardWillChangeFrame(_ notification:Notification){

        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else{
            return
        }

        let keyboardTop = view.bounds.height - max(0, view.bounds.height - keyboardFrame.origin.y)

        //Keep the card vertically centered in the space above the keyboard
        let visibleHeight = min(keyboardTop, view.bounds.height)
        let offset = (visibleHeight / 2) - (view.bounds.height / 2)

        cardCenterYConstraint?.constant = min(-20, offset + 20)

        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }
}
