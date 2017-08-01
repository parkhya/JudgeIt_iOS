//
//  CreateChoiceTableViewCell.swift
//  Judge it!
//
//  Created by Axel Katerbau on 18.08.16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import UIKit
import KMPlaceholderTextView
import AVFoundation
import OpalImagePicker
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}


class CreateChoiceTableViewCell: UITableViewCell, OpalImagePickerControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var choiceNumberLabel: UILabel!
    @IBOutlet var textView: KMPlaceholderTextView!
    @IBOutlet var urlLabel: UILabel!
    @IBOutlet var removeButton: UIButton!
    @IBOutlet var allMediaButtons: Array<UIButton>!
    @IBOutlet var addButton: UIButton!
    @IBOutlet var cameraButton: UIButton!
    @IBOutlet var photoLibraryButton: UIButton!
    weak var tableViewController: UIViewController?
    
    var choice: Choice!
    var choiceNumber: Int!
    
    var scrollHandler: ((UITableViewCell)->())?
    var addDateHandler: (([Date])->())?
    var additionalImageHandler: (([UIImage])->())?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        addButton.isHidden = true
        removeButton.isHidden = true
    }
    
    override func awakeFromNib() {
        let layer = iconImageView.layer
        layer.borderWidth = 1
        layer.borderColor = UIColor.judgeItBorderColor.cgColor
        layer.masksToBounds = true
        layer.cornerRadius = iconImageView.frame.size.width / 2
        
        addButton.layer.borderWidth = 0
        addButton.layer.cornerRadius = addButton.frame.size.width / 2
        addButton.layer.masksToBounds = true
        
        textView.layer.cornerRadius = 5
        textView.layer.borderWidth = 1
        textView.layer.masksToBounds = true
        textView.contentInset = UIEdgeInsets.zero
        
        urlLabel.addGestureRecognizer(UITapGestureRecognizer(target:self, action:#selector(choiceUrlTapped)))
        
        iconImageView.addGestureRecognizer(UITapGestureRecognizer(target:self, action:#selector(removeMedia)))
        
        for mediaButton in allMediaButtons {
            let icon = mediaButton.imageView?.image;
            let borderedIcon = icon?.imageWithAddedBorder(20, color: UIColor.red)
            mediaButton.imageView?.image = borderedIcon
            mediaButton.imageView?.contentMode = .scaleAspectFit
            
            mediaButton.backgroundColor = UIColor.clear
            mediaButton.layer.cornerRadius = mediaButton.frame.size.width / 2
            mediaButton.layer.borderWidth = 1
            mediaButton.layer.masksToBounds = true
            mediaButton.layer.borderColor = UIColor.judgeItBorderColor.cgColor
        }
        
        let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        if !cameraAvailable {
            cameraButton.superview?.removeFromSuperview()
        }
        
        let photoLibraryAvailable = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
        if !photoLibraryAvailable {
            photoLibraryButton.superview?.removeFromSuperview()
        }
    }
    
    func setChoice(_ choice: Choice, choiceNumber: Int, editable: Bool, scrollHandler: ((UITableViewCell)->())?, addDateHandler: ((([Date])->()))?, additionalImageHandler: (([UIImage])->())?) {
        self.choice = choice
        self.choiceNumber = choiceNumber
        self.scrollHandler = scrollHandler
        self.addDateHandler = addDateHandler
        self.additionalImageHandler = additionalImageHandler
        
        textView.layer.borderWidth = editable ? 1.0 : 0.0
        textView.layer.borderColor = editable ? UIColor.judgeItBorderColor.cgColor : UIColor.white.cgColor
        
        textView.placeholder = NSLocalizedString("choice_choice", comment: "") + " \(choiceNumber + 1)";
        textView.backgroundColor = editable ? UIColor.white : UIColor(red: 0xEF, green: 0xEF, blue: 0xEF)
        textView.isEditable = editable
        //        let tap = UITapGestureRecognizer(target:self, action:#selector(touchTextView))
        //        textView.addGestureRecognizer(tap)
        
        iconImageView.contentMode = choice.picture != nil ? .scaleAspectFill : .center
        if (choice.photoId?.length > 0 && choice.picture == nil) {
            // load picture:
            choice.photo({ (image, error) in
                if let image = image {
                    self.iconImageView.image = image
                    self.iconImageView.contentMode = .scaleAspectFill
                }
            })
        }
        
        iconImageView.image = choice.picture
        iconImageView.isUserInteractionEnabled = editable
        
        choiceNumberLabel.text = " \(choiceNumber + 1)"
        choiceNumberLabel.isHidden = choice.picture != nil
        
        removeButton.isHidden = !editable
        
        for mediaButton in allMediaButtons {
            mediaButton.isEnabled = editable
        }
        
        //let choiceText = try! NSMutableAttributedString(data: choice.text.dataUsingEncoding(NSUnicodeStringEncoding, allowLossyConversion: true)!,
        //                                                options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType],
        //                                                documentAttributes: nil)
        //        choiceText.addAttributes([NSFontAttributeName: UIFont.systemFontOfSize(16)], range: (choiceText.string as NSString).rangeOfString(choiceText.string))
        
        NotificationCenter.default.addObserver(self, selector: #selector(CreateChoiceTableViewCell.keyboardDidShow(_:)), name:NSNotification.Name.UIKeyboardWillShow, object: nil)
        
        //textView.attributedText = choiceText
        textView.text = choice.text
        urlLabel.text = choice.url()?.absoluteString ?? ""
    }
    
    
    
    func keyboardDidShow(_ sender: Notification) {
        if(textView.isFirstResponder){
            scrollHandler?(self)
        }
    }
    
    func touchTextView(_ sender: UITextView){
        scrollHandler?(self)
    }
    
    func choiceUrlTapped(_ sender: UITapGestureRecognizer) {
        if let url = self.choice.url() {
            UIApplication.shared.openURL(url as URL)
        }
    }
    
    @IBAction func addMediaFromGallery(_ sender: UIButton) {
        self.pickImage(.photoLibrary)
    }
    
    @IBAction func addMediaFromCamera(_ sender: UIButton) {
        self.pickImage(.camera)
    }
    
    @IBAction func addLink(_ sender: UIButton) {
        let urlAlert = UIAlertController(title: NSLocalizedString("pick_url", comment: ""), message: nil, preferredStyle: UIAlertControllerStyle.alert)
        urlAlert.addTextField(configurationHandler: {textField in
            textField.placeholder = NSLocalizedString("pick_url_hint", comment: "")
            textField.keyboardType = .URL
            textField.addTarget(self, action: #selector(self.urlEditChanged), for: .editingChanged)
        })
        
        // bad style to use localized strings whose name bear a different semantic. Here it is just "cancel" and "ok".
        urlAlert.addAction(UIAlertAction(title: NSLocalizedString("cancel",comment:""), style: .cancel, handler: nil))
        urlAlert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .default, handler: { alertAction in
            let urlText = urlAlert.textFields![0].text!
            let url = URL.URL(string: urlText, fallbackSchemeWithDivider: "http://")
            self.choice.text = url?.absoluteString ?? ""
            self.setChoice(self.choice, choiceNumber: self.choiceNumber, editable: true, scrollHandler: self.scrollHandler, addDateHandler: self.addDateHandler, additionalImageHandler: self.additionalImageHandler)
            
            self.textView.becomeFirstResponder()
            self.scrollHandler?(self)
        }))
        (urlAlert.actions[1] as UIAlertAction).isEnabled = false
        tableViewController!.present(urlAlert, animated: true, completion: nil)
    }
    
    @IBAction func addDate(_ sender: UIButton) {
        let dateAlert = UIAlertController(title: NSLocalizedString("pick_date", comment: ""), message: nil, preferredStyle: UIAlertControllerStyle.alert)
        let dateView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "NewDatePickerController") as! NewDatePickerController
        dateAlert.setValue(dateView, forKey: "contentViewController")
        dateAlert.addAction(UIAlertAction(title: NSLocalizedString("cancel",comment:""), style: .cancel, handler: nil))
        //        dateAlert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .Default, handler: { alertAction in
        //            var dateString = NSDate.timeString(fromUnixTime: dateView.datePicker.date.timeIntervalSince1970, weekDay: true)
        //
        //            if(!dateView.timeframePicker.hidden){
        //                dateString += " - " + NSDate.timeString(fromUnixTime: dateView.timeframePicker.date.timeIntervalSince1970, weekDay: true)
        //            }
        //
        //            self.choice.text = dateString
        //            self.setChoice(self.choice, choiceNumber: self.choiceNumber, editable: true, scrollHandler: self.scrollHandler)
        //
        //            self.textView.resignFirstResponder()
        //        }))
        
        dateAlert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .default, handler: { alertAction in
            var dateString = ""
            
            let dates = dateView.dates.sorted()
            
            if let date = dates.first {
                dateString = Date.dateString(fromUnixTime: date.timeIntervalSince1970, weekDay: true)
            }
            if let timeframe = dateView.timeframe, dateView.isTimeframe {
                dateString =  Date.dateString(fromUnixTime: timeframe.0.timeIntervalSince1970, weekDay: true)
                if(timeframe.0 != timeframe.1){
                    dateString += " - " + Date.dateString(fromUnixTime: timeframe.1.timeIntervalSince1970, weekDay: true)
                }
            }
            
            self.choice.text = dateString
            self.setChoice(self.choice, choiceNumber: self.choiceNumber, editable: true, scrollHandler: self.scrollHandler, addDateHandler: self.addDateHandler, additionalImageHandler: self.additionalImageHandler)
            
            self.textView.resignFirstResponder()
            
            if(dates.count > 1 && !dateView.isTimeframe){
                self.addDateHandler?(Array(dates.suffix(from: 1)) as [Date])
            }
        }))
        
        tableViewController!.present(dateAlert, animated: true, completion: nil)
    }
    
    func removeMedia(_ sender: UITapGestureRecognizer) {
        if self.choice.url() != nil || self.choice.picture != nil {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("pick_remove", comment: ""), style: .destructive){ alertAction in
                self.choice.text = ""
                self.choice.picture = nil
                self.setChoice(self.choice, choiceNumber: self.choiceNumber, editable: true, scrollHandler: self.scrollHandler, addDateHandler: self.addDateHandler, additionalImageHandler: self.additionalImageHandler)
            })
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("cancel",comment:""), style: .cancel, handler: nil))
            
            alert.popoverPresentationController?.sourceView = sender.view
            alert.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: sender.view!.center.x - sender.view!.frame.origin.x, y: sender.view!.center.y - sender.view!.frame.origin.y), size: CGSize(width: 0, height: 0))
            
            tableViewController!.present(alert, animated: true, completion: nil)
        }
    }
    
    func urlEditChanged(_ sender: UITextField){
        var resp:UIResponder = sender
        while !(resp is UIAlertController) { resp = resp.next! }
        let alert = resp as! UIAlertController
        
        if sender.text?.length > 0
            && (URL.URL(string: sender.text!, fallbackSchemeWithDivider: "http://")) != nil {
            (alert.actions[1] as UIAlertAction).isEnabled = true
        } else {
            (alert.actions[1] as UIAlertAction).isEnabled = false
        }
    }
    
    func pickImage(_ sourceType: UIImagePickerControllerSourceType) {
        if sourceType == .camera {
            let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
            switch(authStatus) {
            case .denied, .restricted:
                // TODO: maybe alert here for proposing to change the access setting in Settings
                return
            case .notDetermined:
                AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (hasBeenGranted) in
                    // Called from an arbitraty thread – swiitch to main thread:
                    DispatchQueue.main.async(execute: {
                        if hasBeenGranted {
                            self.pickImage(sourceType)
                        }
                    })
                })
                return
            default:
                break
            }
        }
        
        if(sourceType == .camera){
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.allowsEditing = UIDevice.current.modelName.hasPrefix("iPad") ? false : true
            imagePicker.sourceType = sourceType
            tableViewController!.present(imagePicker, animated: true, completion: nil)
        } else {
            let imagePicker = OpalImagePickerController()
            imagePicker.imagePickerDelegate = self
            tableViewController!.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerEditedImage] as? UIImage ?? info[UIImagePickerControllerOriginalImage] as? UIImage {
            choice.picture = pickedImage
            //choice.text = ""
            choice.pictureString = ""
            
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
                let picture_small = pickedImage.resizeToWidth(500)
                let imageData = UIImageJPEGRepresentation(picture_small, 0.95)
                self.choice.pictureString = imageData?.base64EncodedString(options: .lineLength64Characters)
            })
            
            setChoice(choice, choiceNumber: self.choiceNumber, editable: true, scrollHandler: self.scrollHandler, addDateHandler: self.addDateHandler, additionalImageHandler: self.additionalImageHandler)
        }
        
        picker.dismiss(animated: true, completion: {
            self.textView.becomeFirstResponder()
            self.scrollHandler?(self)
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePicker(_ picker: OpalImagePickerController, didFinishPickingImages images: [UIImage]){
        if let image = images.first {
            choice.picture = image
            //choice.text = ""
            choice.pictureString = ""
            
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
                let picture_small = image.resizeToWidth(500)
                let imageData = UIImageJPEGRepresentation(picture_small, 0.95)
                self.choice.pictureString = imageData?.base64EncodedString(options: .lineLength64Characters)
            })
            
            setChoice(choice, choiceNumber: self.choiceNumber, editable: true, scrollHandler: self.scrollHandler, addDateHandler: self.addDateHandler, additionalImageHandler: self.additionalImageHandler)
        }
        
        picker.dismiss(animated: true, completion: {
            self.textView.becomeFirstResponder()
            self.scrollHandler?(self)
        })
        
        if images.count > 1 {
            self.additionalImageHandler?(Array(images.suffix(from: 1)))
        }
    }
    
    func imagePickerDidCancel(_ picker: OpalImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    
}
