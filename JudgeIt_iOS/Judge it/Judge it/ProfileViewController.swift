//
//  ProfileViewController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 10/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import libPhoneNumber_iOS
import CoreTelephony

class ProfileViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var profilePictureImageView: UIImageView!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var statusField: UITextField!
    @IBOutlet weak var phoneField: UITextField!
    @IBOutlet var emailLabel: UILabel!
    @IBOutlet var phoneSubtitle: UILabel!
    
    @IBOutlet weak var progressIndicator: UIActivityIndicatorView!
    
    var profileUser: User?
    
    lazy var imagePicker = UIImagePickerController()
    
    static let phoneRegion = { () -> String in
        let temp = CTTelephonyNetworkInfo().subscriberCellularProvider?.isoCountryCode ?? "DE"
        return temp.substring(to: temp.index(temp.startIndex, offsetBy: 2))
    }()
    let phoneUtil = NBPhoneNumberUtil()
    let phoneFormatter = NBAsYouTypeFormatter(regionCode: phoneRegion)
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.localizeStrings()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.reload(forced: true)
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        progressIndicator.isHidden = true
        
        profilePictureImageView.layer.borderWidth = 1.0
        profilePictureImageView.layer.masksToBounds = false
        profilePictureImageView.layer.borderColor = UIColor.white.cgColor
        profilePictureImageView.layer.cornerRadius = profilePictureImageView.frame.size.height/2
        profilePictureImageView.clipsToBounds = true
        
        phoneField.delegate = self
        phoneField.layer.borderWidth = 1.0
        phoneField.layer.cornerRadius = 5
        phoneField.clipsToBounds = true
        phoneField.layer.borderColor = UIColor.clear.cgColor
        
        statusField.delegate = self
        usernameField.delegate = self
        
        let tapGestureRecognizer = UITapGestureRecognizer(target:self, action: #selector(imageSelected))
        profilePictureImageView.isUserInteractionEnabled = true
        profilePictureImageView.addGestureRecognizer(tapGestureRecognizer)
        
        imagePicker.delegate = self
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        self.navigationItem.hidesBackButton = true
        let saveButton = UIBarButtonItem(image: UIImage(named: "ic_done_ios"), style: .done, target: self, action: #selector(showPhonePopup))
        self.navigationItem.rightBarButtonItem = saveButton
        
        //        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillShow:"), name:UIKeyboardWillShowNotification, object: nil);
        //        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillHide:"), name:UIKeyboardWillHideNotification, object: nil);
    }
    
    func showPhonePopup(){
        if profileUser?.phoneNumberHash == nil && !UserDefaults.standard.bool(forKey: "AskedForPhoneNumber") {
            let phoneAlertController = UIAlertController(title: nil, message: NSLocalizedString("[Phone Number Missing Alert Message]", comment: ""), preferredStyle: .alert)
            phoneAlertController.addAction(UIAlertAction(title: NSLocalizedString("Back", comment: ""), style: .default, handler: { (action) in
                // Make phone field first responder here?
                self.phoneField.becomeFirstResponder()
            }))
            phoneAlertController.addAction(UIAlertAction(title: NSLocalizedString("Next", comment: ""), style: .default, handler: { (action) in
                UserDefaults.standard.set(true, forKey: "AskedForPhoneNumber")
                self.navigationController?.popViewController(animated: true)
            }))
            
            self.present(phoneAlertController, animated: true, completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func validateUI() {
        //        if isRegistrationCompletion {
        //            let isUsernameValid = usernameField.text?.length > 2
        //            self.navigationItem.rightBarButtonItem?.enabled = isUsernameValid
        //        }
        
        if let phoneNumberText = phoneField.text, phoneNumberText.characters.count > 0 {
            phoneField.layer.borderColor = phoneNumberText.isValidPhoneNumber(ProfileViewController.phoneRegion) ? UIColor.clear.cgColor : UIColor.red.cgColor
        } else {
            phoneField.layer.borderColor = UIColor.clear.cgColor
        }
    }
    
    func reload(forced: Bool = false) {
        User.fetchProfile(alsoCached: !forced) { (profileUser, error) in
            if let profileUser = profileUser {
                self.profileUser = profileUser
                
                if self.view != nil {
                    self.usernameField.text = profileUser.username
                    self.emailLabel.text = profileUser.emailAddress ?? "--"
                    self.phoneField.text = GlobalQuestionData.phoneNumber
                    self.phoneField.placeholder = profileUser.phoneNumberHash != nil ? NSLocalizedString("phone_unchanged",comment:"") : nil
                    
                    self.statusField.text = profileUser.statusText
                    
                    self.profileUser?.fetchPhoto { (photo, error) in
                        if let photo = photo {
                            if profileUser === self.profileUser {
                                self.profilePictureImageView.image = photo
                                self.profilePictureImageView.contentMode = .scaleAspectFill
                            }
                        }
                    }
                    
                    self.validateUI()
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    
//        self.navigationController?.navigationBar.backItem?.backBarButtonItem?.target = self
//        self.navigationController?.navigationBar.backItem?.backBarButtonItem?.action = #selector(showPhonePopup)
        
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "Profile")
        tracker?.send((GAIDictionaryBuilder.createScreenView().build() as NSDictionary) as! [AnyHashable: Any])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissKeyboard()
    }
    
    func dismissKeyboard(){
        view.endEditing(true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === usernameField {
            statusField.becomeFirstResponder()
            return true
        } else if textField === statusField {
            phoneField.becomeFirstResponder()
            return true
        } else if textField == phoneField {
            view.endEditing(true)
            return true
        }
        return false
    }
    
    //    var keyboardShown = false
    //    func keyboardWillShow(sender: NSNotification) {
    //        if(!keyboardShown){
    //            self.view.frame.origin.y -= isRegistrationCompletion ? 175 : 150
    //        }
    //        keyboardShown = true
    //    }
    //
    //    func keyboardWillHide(sender: NSNotification) {
    //        if(keyboardShown){
    //            self.view.frame.origin.y += isRegistrationCompletion ? 175 : 150
    //        }
    //        keyboardShown = false
    //    }
    
    func imageSelected(_ sender:UITapGestureRecognizer){
        
        let alert = UIAlertController(title: NSLocalizedString("pick_image_source", comment:""), message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("pick_image_from_photo", comment: ""), style: .default){ alertAction in
            self.imagePicker.allowsEditing = true
            self.imagePicker.sourceType = .camera
            
            self.present(self.imagePicker, animated: true, completion: nil)
        })
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("pick_image_from_gallery", comment: ""), style: .default){ alertAction in
            self.imagePicker.allowsEditing = true
            self.imagePicker.sourceType = .photoLibrary
            
            self.present(self.imagePicker, animated: true, completion: nil)
        })
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel",comment:""), style: .cancel, handler: nil))
        
        alert.popoverPresentationController?.sourceView = sender.view
        alert.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: sender.view!.center.x - sender.view!.frame.origin.x, y: sender.view!.center.y - sender.view!.frame.origin.y), size: CGSize(width: 0, height: 0))
        
        present(alert, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerEditedImage] as? UIImage ?? info[UIImagePickerControllerOriginalImage] as? UIImage {
            profilePictureImageView.image = pickedImage
            profilePictureImageView.contentMode = .scaleAspectFill
            
            self.progressIndicator.isHidden = false
            User.patchProfile(photo: pickedImage) { (error) in
                self.progressIndicator.isHidden = true
                if error != nil {
                    self.reload(forced: true)
                }
            }
            
            validateUI()
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func logout(_ sender: AnyObject) {
        AppDelegate.logout()
    }
    
    var cancelableBlockUsername: dispatch_cancelable_block_t?
    var cancelableBlockStatusText: dispatch_cancelable_block_t?
    var cancelableBlockPhoneNumber: dispatch_cancelable_block_t?
    
    @IBAction func textFieldDidChange(_ textField: UITextField) {
        if let text = textField.text {
            if textField === self.usernameField {
                cancel_block(cancelableBlockUsername)
                cancelableBlockUsername = dispatch_after_delay(1.5) {
                    if text.characters.count > 2 {
                        self.progressIndicator.isHidden = false
                        User.patchProfile(username: text) { (error) in
                            self.progressIndicator.isHidden = true
                            if error != nil {
                                self.reload(forced: true)
                            }
                        }
                    } else {
                        let alertController = UIAlertController(title: NSLocalizedString("update_username_short", comment: "Profile username too short - title"), message: NSLocalizedString("username_short_body", comment: "Profile username too short - body"), preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default, handler: nil))
                        self.present(alertController, animated: true) {}
                    }
                }
            } else if textField === self.statusField {
                cancel_block(cancelableBlockStatusText)
                cancelableBlockStatusText = dispatch_after_delay(1.5) {
                    self.progressIndicator.isHidden = false
                    User.patchProfile(statusText: text) { (error) in
                        self.progressIndicator.isHidden = true
                        if error != nil {
                            self.reload()
                        }
                    }
                }
            } else if textField === self.phoneField {
                let isValidNumber = text.isValidPhoneNumber(ProfileViewController.phoneRegion)
                self.validateUI()
                cancel_block(cancelableBlockPhoneNumber)
                cancelableBlockPhoneNumber = dispatch_after_delay(1.5) {
                    if isValidNumber || text.length==0 {
                        self.progressIndicator.isHidden = false
                        User.patchProfile(phoneNumber: text) { (error) in
                            self.progressIndicator.isHidden = true
                            if error == nil {
                                GlobalQuestionData.phoneNumber = text
                                self.reload()
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    //    override func scrollViewDidScroll(scrollView: UIScrollView) {
    //        if OPKeyboardStateListener.sharedInstance().isVisible() {
    //            self.dismissKeyboard()
    //        }
    //    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var title: String? = nil
        
        switch section {
        case 1:
            title = "email_address-title"
        case 2:
            title = "username_title"
        case 3:
            title = "statustext_title"
        case 4:
            title = "phonenumber_title"
        default:
            break
        }
        
        return title == nil ? nil : NSLocalizedString(title!, comment: "")
    }
    
    //    @IBAction func confirm(sender: AnyObject?){
    //
    //        let nullablePicture = profilePicture.image != nil ? profilePicture.image : nil
    //        let usernameText = usernameField.text ?? ""
    //        let statusText = statusField.text ?? NSLocalizedString("profile_default_status", comment: "Default status text")
    //        let phoneNumber = phoneField.text ?? ""
    //
    //        if(usernameText.characters.count > 2){
    //
    //            do {
    //                let nbPhoneNumber: NBPhoneNumber = try phoneUtil.parse(phoneNumber, defaultRegion: ProfileViewController.phoneRegion)
    //                if(phoneUtil.isValidNumber(nbPhoneNumber)){
    //                    let formattedPhone: String = try phoneUtil.format(nbPhoneNumber, numberFormat: .E164)
    //                    print(formattedPhone)
    //                    phoneField.text = formattedPhone
    //
    //                    progressIndicator.hidden = false
    //                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), {
    //                        UpdateProfileTask.updateProfile(usernameText, statusText: statusText, phoneNumber: formattedPhone,
    //                            nullablePicture: nullablePicture, delegate: UpdateProfileDelegate(parent: self))
    //                    })
    //
    //                    if self.isRegistrationCompletion {
    //                        self.performSegueWithIdentifier("home", sender: self)
    //                    }
    //                } else if(GlobalQuestionData.phoneIsSet && phoneNumber.length <= 0){
    //                    progressIndicator.hidden = false
    //                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), {
    //                        UpdateProfileTask.updateProfile(usernameText, statusText: statusText, phoneNumber: nil,
    //                            nullablePicture: nullablePicture, delegate: UpdateProfileDelegate(parent: self))
    //                    })
    //                } else {
    //                    showPhoneInvalid()
    //                }
    //            } catch let error as NSError {
    //                if(GlobalQuestionData.phoneIsSet && phoneNumber.length <= 0){
    //                    progressIndicator.hidden = false
    //                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), {
    //                        UpdateProfileTask.updateProfile(usernameText, statusText: statusText, phoneNumber: nil,
    //                            nullablePicture: nullablePicture, delegate: UpdateProfileDelegate(parent: self))
    //                    })
    //                } else {
    //                    print(error.localizedDescription)
    //
    //                    showPhoneInvalid()
    //                }
    //            } catch{
    //                if(GlobalQuestionData.phoneIsSet && phoneNumber.length <= 0){
    //                    progressIndicator.hidden = false
    //                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), {
    //                        UpdateProfileTask.updateProfile(usernameText, statusText: statusText, phoneNumber: nil,
    //                            nullablePicture: nullablePicture, delegate: UpdateProfileDelegate(parent: self))
    //                    })
    //                } else {
    //                    showPhoneInvalid()
    //                }
    //            }
    //        } else{
    //            let alert = UIAlertView()
    //            alert.title = NSLocalizedString("update_username_short", comment: "Profile username too short - title")
    //            alert.message = NSLocalizedString("username_short_body", comment: "Profile username too short - body")
    //            alert.addButtonWithTitle(NSLocalizedString("ok", comment: "OK"))
    //            alert.show()
    //        }
    //
    //    }
    
    //    func showPhoneInvalid(){
    //        let alert = UIAlertView()
    //        alert.title = NSLocalizedString("string_phone_field", comment: "")
    //        alert.message = NSLocalizedString("phone_error", comment: "")
    //        alert.addButtonWithTitle(NSLocalizedString("ok", comment: "OK"))
    //        alert.show()
    //    }
    
    //    class UpdateProfileDelegate : UpdateProfileTask.UpdateProfileTaskDelegate {
    //
    //        var parent:ProfileViewController
    //
    //        init(parent: ProfileViewController){
    //            self.parent = parent
    //        }
    //
    //        override func onPostExecute(result: Bool) {
    //            dispatch_async(dispatch_get_main_queue(), {
    //                if(result){
    //                    if(!(GlobalQuestionData.phoneIsSet && self.parent.phoneField.text?.length <= 0)){
    //                        GlobalQuestionData.phoneNumber = self.parent.phoneField.text ?? GlobalQuestionData.phoneNumber
    //
    //                        let prefs = NSUserDefaults.standardUserDefaults()
    //                        prefs.setSecretObject(self.parent.phoneField.text ?? GlobalQuestionData.phoneNumber, forKey: "phone_number")
    //                    }
    //
    //                    let user = GlobalQuestionData.userMap[GlobalQuestionData.user_id]
    //                    user?.picture = (self.parent.profilePicture.image != nil ? self.parent.profilePicture.image : nil) ?? user?.picture
    //                    user?.username = self.parent.usernameField.text ?? (user?.username)!
    //                    user?.statusText = self.parent.statusField.text ?? (user?.statusText)!
    //                }
    //                self.parent.progressIndicator.hidden = true
    //                if self.parent.isRegistrationCompletion  {
    //                    self.parent.performSegueWithIdentifier("home", sender: self.parent)
    //                }
    //            })
    //        }
    //    }
    
}

extension String {
    
    func isValidPhoneNumber(_ defaultPhoneRegion: String?) -> Bool {
        do {
            let parsedPhoneNumber: NBPhoneNumber = try phoneUtil.parse(self, defaultRegion: defaultPhoneRegion)
            return phoneUtil.isValidNumber(parsedPhoneNumber)
        } catch {
            return false
        }
    }
    
}
