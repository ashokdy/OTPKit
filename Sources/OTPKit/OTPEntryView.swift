//
//  OTPEntryView.swift
//  OTPKit
//
//  Copyright © 2026 SalesXRM. All rights reserved.
//

import UIKit

///The reusable OTP digit-entry row: N glossy boxes backed by one invisible
///text field. Drop it into a xib/storyboard (set `numberOfDigits` in code or
///as a runtime attribute) or create it programmatically.
///
///    let entryView = OTPEntryView()
///    entryView.numberOfDigits = 6
///    entryView.onCodeEntered = { code in ... }
///    entryView.beginEntry()
public class OTPEntryView: UIView, UITextFieldDelegate {

    //MARK: - Configuration

    ///Number of digit boxes. Changing it rebuilds the row and clears any input.
    @IBInspectable public var numberOfDigits: Int = 6{
        didSet{
            guard numberOfDigits != oldValue else { return }
            rebuildBoxes()
        }
    }

    public var theme = OTPTheme(){
        didSet{
            digitBoxes.forEach({ $0.theme = theme })
        }
    }

    ///Fired every time a digit is added/removed
    public var onCodeChanged:((_ code:String)->Void)? = nil

    ///Fired when all digits are filled
    public var onCodeEntered:((_ code:String)->Void)? = nil

    //MARK: - State

    ///Digits entered so far
    public var code:String{
        return hiddenTextField.text ?? ""
    }

    ///While locked (e.g. after success) input is ignored
    public private(set) var isLocked = false

    //MARK: - UI

    private let boxesStackView = UIStackView()
    private var digitBoxes:[OTPDigitBox] = []
    private let hiddenTextField = UITextField()

    private var boxSize:CGFloat{
        return numberOfDigits > 5 ? 44 : 52
    }

    private var boxSpacing:CGFloat{
        return numberOfDigits > 5 ? 8 : 12
    }

    //MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup(){

        boxesStackView.translatesAutoresizingMaskIntoConstraints = false
        boxesStackView.axis = .horizontal
        boxesStackView.distribution = .fillEqually
        addSubview(boxesStackView)

        NSLayoutConstraint.activate([
            boxesStackView.topAnchor.constraint(equalTo: topAnchor),
            boxesStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            boxesStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            boxesStackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            boxesStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])

        hiddenTextField.translatesAutoresizingMaskIntoConstraints = false
        hiddenTextField.keyboardType = .numberPad
        hiddenTextField.textContentType = .oneTimeCode
        hiddenTextField.delegate = self
        hiddenTextField.addTarget(self, action: #selector(otpTextChanged), for: .editingChanged)

        //Invisible but NOT hidden — a hidden field can't (re)become first
        //responder, which kills the keyboard for good once it's dismissed.
        hiddenTextField.alpha = 0.02
        hiddenTextField.tintColor = .clear

        addSubview(hiddenTextField)

        NSLayoutConstraint.activate([
            hiddenTextField.centerXAnchor.constraint(equalTo: boxesStackView.centerXAnchor),
            hiddenTextField.centerYAnchor.constraint(equalTo: boxesStackView.centerYAnchor),
            hiddenTextField.widthAnchor.constraint(equalToConstant: 1),
            hiddenTextField.heightAnchor.constraint(equalToConstant: 1)
        ])

        //Tapping the boxes (re)summons the number pad if it was dismissed
        let tap = UITapGestureRecognizer(target: self, action: #selector(boxesTapped))
        addGestureRecognizer(tap)

        rebuildBoxes()
    }

    private func rebuildBoxes(){

        digitBoxes.forEach({ $0.removeFromSuperview() })
        digitBoxes.removeAll()

        boxesStackView.spacing = boxSpacing

        for _ in 0..<max(1, numberOfDigits){

            let box = OTPDigitBox()
            box.translatesAutoresizingMaskIntoConstraints = false
            box.theme = theme
            box.widthAnchor.constraint(equalToConstant: boxSize).isActive = true
            box.heightAnchor.constraint(equalToConstant: boxSize + 8).isActive = true

            digitBoxes.append(box)
            boxesStackView.addArrangedSubview(box)
        }

        hiddenTextField.text = ""
        isLocked = false
        updateBoxes()
        invalidateIntrinsicContentSize()
    }

    public override var intrinsicContentSize: CGSize{

        let count = CGFloat(max(1, numberOfDigits))
        return CGSize(width: count * boxSize + (count - 1) * boxSpacing,
                      height: boxSize + 8)
    }

    //MARK: - Public Controls

    ///Summons the number pad
    public func beginEntry(){
        hiddenTextField.becomeFirstResponder()
    }

    public func endEntry(){
        hiddenTextField.resignFirstResponder()
    }

    ///Clears the input and returns the boxes to their normal look
    public func reset(){

        isLocked = false
        hiddenTextField.text = ""
        digitBoxes.forEach({ $0.state = .normal })
        updateBoxes()
    }

    ///Marks all boxes green and locks further input
    public func showSuccess(){

        isLocked = true
        hiddenTextField.resignFirstResponder()
        digitBoxes.forEach({ $0.state = .success })
        updateBoxes()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    ///Marks all boxes red, then clears and refocuses after a beat
    public func showFailure(){

        digitBoxes.forEach({ $0.state = .failure })

        UINotificationFeedbackGenerator().notificationOccurred(.error)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in

            guard let self = self, self.isLocked == false else { return }

            self.reset()
            self.hiddenTextField.becomeFirstResponder()
        }
    }

    //MARK: - UITextField Delegate Methods

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {

        if isLocked{
            return false
        }

        //Digits only
        if string.isEmpty == false && CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string)) == false{
            return false
        }

        let currentText = (textField.text ?? "") as NSString
        let updatedText = currentText.replacingCharacters(in: range, with: string)

        return updatedText.count <= numberOfDigits
    }

    //MARK: - Private

    @objc private func otpTextChanged(){

        updateBoxes()

        let entered = hiddenTextField.text ?? ""

        onCodeChanged?(entered)

        if entered.count == numberOfDigits{
            onCodeEntered?(entered)
        }
    }

    @objc private func boxesTapped(){

        guard !isLocked else{
            return
        }

        if hiddenTextField.isFirstResponder{

            //On iPad the keyboard-dismiss key hides the number pad while the
            //field STAYS first responder, so becomeFirstResponder() alone is a
            //no-op. Bounce the responder to force the keyboard back.
            hiddenTextField.resignFirstResponder()

            DispatchQueue.main.async { [weak self] in
                self?.hiddenTextField.becomeFirstResponder()
            }
        }
        else{
            hiddenTextField.becomeFirstResponder()
        }
    }

    private func updateBoxes(){

        let entered = Array(hiddenTextField.text ?? "")

        for (index,box) in digitBoxes.enumerated(){

            box.digitLabel.text = index < entered.count ? String(entered[index]) : ""
            box.isActive = (index == entered.count) && !isLocked
        }
    }
}
