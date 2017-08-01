//
//  CommentFragmentController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 06/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation
import TTTAttributedLabel
import Adjust
import IQKeyboardManagerSwift
import AudioToolbox
import AVFoundation
import NYTPhotoViewer
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


class CommentFragmentController : UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, TTTAttributedLabelDelegate, QuestionFragment, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    
    var questionId: String?
    var questionText: String?
    
    var followupComments: [Comment]?
    var comments: [Comment]?
    
    var question: Question?
    
    let imageCache = NSCache<AnyObject, AnyObject>()
    var isReloadSuspended = false
    
    @IBOutlet var commentField: UITextView!
    
    @IBOutlet var chatView: UIView!
    @IBOutlet var chatViewBottomConstraint: NSLayoutConstraint!
    var defaultBottomConstraint:CGFloat?
    
    var selfBubble:UIImage?
    var otherBubble:UIImage?
    
    var sentSoundID: SystemSoundID {
        let filePath = Bundle.main.path(forResource: "SentMessage", ofType: "mp3")
        let soundURL = URL(fileURLWithPath: filePath!)
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
        return soundID
    }
    
    var receivedSoundID: SystemSoundID {
        let filePath = Bundle.main.path(forResource: "ReceivedMessage", ofType: "mp3")
        let soundURL = URL(fileURLWithPath: filePath!)
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
        return soundID
    }
    
    @IBOutlet var backgroundImage: UIImageView!
    
    lazy var imagePicker = UIImagePickerController()
    
    @IBOutlet var tableView: UITableView!
    
    func passQuestion(_ question:Question){
        self.question = question // just for conforming to protocol for now
        
        self.questionId = question.id
        self.questionText = question.text
        
        // TODO: add comments from followed-up questions in front
        //            var tempQuestion:Question? = question
        //            while let followupId = tempQuestion?.followup {
        //                tempQuestion = GlobalQuestionData.questionMap[followupId]
        //                if(tempQuestion != nil){
        //                    for comment in tempQuestion!.comments.reverse(){
        //                        followupList!.insert(comment, atIndex: 0)
        //                    }
        //                }
        //            }
        
        reload(scrollToEnd: true)
    }
    
    func reload(scrollToEnd: Bool, ignoreCache: Bool = false) {
        if isReloadSuspended {
            return
        }
        
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
            Comment.fetchFollowedUpComments(self.question!) { (followupComments, error) in
                DispatchQueue.main.async(execute: {
                    if let followupComments = followupComments {
                        self.followupComments = followupComments
                        if self.view != nil {
                            self.tableView.reloadData()
                        }
                        
                        //                        if scrollToEnd {
                        //                            self.myScrollToEnd()
                        //                        }
                    }
                })
            }
        })
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
            Comment.fetchComments(questionId: self.questionId!, commentId: nil, alsoCached: !ignoreCache) { (comments, error) in
                DispatchQueue.main.async(execute: {
                    if let comments = comments {
                        if self.comments == nil || !comments.elementsEqual(self.comments!, by: ==) {
                            self.comments = comments
                            
                            self.makeCommentsSeen()
                            
                            if self.view != nil {
                                self.tableView.reloadData()
                            }
                        }
                        
                        //                        if scrollToEnd {
                        //                            self.myScrollToEnd()
                        //                        }
                    }
                })
            }
        })
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.automaticallyAdjustsScrollViewInsets = false
        
        self.tabBarController?.tabBar.isHidden = false
        
        imagePicker.delegate = self
        
        selfBubble = UIImage(contentsOfFile: Bundle.main.path(forResource: "chatbubble_self", ofType: "png")!)
        selfBubble = selfBubble?.resizableImage(withCapInsets: UIEdgeInsetsMake(11, 11, 35, 22), resizingMode: .stretch)
        otherBubble = UIImage(contentsOfFile: Bundle.main.path(forResource: "chatbubble_other", ofType: "png")!)
        otherBubble = otherBubble?.resizableImage(withCapInsets: UIEdgeInsetsMake(33,  19, 11, 11), resizingMode: .stretch)
        
        commentField.clipsToBounds = true
        commentField.layer.cornerRadius = 4.0
        
        tableView.transform = CGAffineTransform(rotationAngle: CGFloat(-M_PI));
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 64
        
        let prefs = UserDefaults.standard
        if let path = prefs.object(forKey: "wallpaper_path") as? String{
            if let dir : NSString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first as NSString?{
                let relativePath = dir.appendingPathComponent(path)
                backgroundImage.image = UIImage(contentsOfFile: relativePath)
            }
        } else if let color = prefs.colorForKey("wallpaper_color"){
            backgroundImage.backgroundColor = color
        }
        
        defaultBottomConstraint = self.chatViewBottomConstraint.constant
        commentField.delegate = self
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(CommentFragmentController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
    }
    
    func applicationDidBecomeActive() {
        self.makeCommentsSeen()
    }
    
    func dismissKeyboard(){
        view.endEditing(true)
    }
    
    var keyboardShown = false
    var kbHeight:CGFloat? = nil
    func keyboardWillShow(_ sender: Notification) {
        if(!ignoreKeyboard){
            if(!keyboardShown){
                
                let kbHeight = (sender.userInfo?[UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue.height
                let tabHeight = (self.question?.isChatOnly ?? false) ? 0 : (self.tabBarController?.tabBar.frame.height ?? 0)
                
                //                print("keyboard height \(kbHeight)")
                self.kbHeight = kbHeight
                
                chatViewBottomConstraint.constant -= (kbHeight - tabHeight)
                
                let tableViewDiff = (kbHeight - tabHeight - self.chatView.frame.height)
                self.tableView.frame.size = CGSize(width: self.tableView.frame.width, height: self.tableView.frame.height - tableViewDiff)
                myScrollToEnd()
            }
            keyboardShown = true
        }
    }
    
    func keyboardWillChange(_ sender: Notification){
        if(!ignoreKeyboard){
            if(keyboardShown){
                if let changedKbHeight = (sender.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height, kbHeight != nil{
                    //                    print("keyboard height \(changedKbHeight)")
                    
                    chatViewBottomConstraint.constant -= (changedKbHeight - self.kbHeight!)
                    
                    self.tableView.frame.size = CGSize(width: self.tableView.frame.width, height: self.tableView.frame.height + (changedKbHeight - self.kbHeight!))
                    
                    myScrollToEnd()
                    
                    self.kbHeight = changedKbHeight
                }
            }
        }
    }
    
    func keyboardWillHide(_ sender: Notification) {
        keyboardHide()
    }
    
    func keyboardHide(){
        if(!ignoreKeyboard){
            if(keyboardShown){
                
                if let kbHeight = self.kbHeight{
                    let tabHeight = self.question!.isChatOnly ? 0 : (self.tabBarController?.tabBar.frame.height ?? 0)
                    
                    self.chatViewBottomConstraint.constant += (kbHeight - tabHeight)
                    
                    let tableViewDiff = (kbHeight - tabHeight - self.chatView.frame.height)
                    self.tableView.frame.size = CGSize(width: self.tableView.frame.width, height: self.tableView.frame.height + tableViewDiff)
                    myScrollToEnd()
                    
                    self.kbHeight = nil
                }
            }
            keyboardShown = false
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(chatInfoClicked))
        tap.delegate = self
        self.navigationController?.navigationBar.addGestureRecognizer(tap)
        
        chatViewBottomConstraint.constant = defaultBottomConstraint!
        self.view.setNeedsUpdateConstraints()
        self.view.updateConstraintsIfNeeded()
        self.view.layoutIfNeeded()
        
        
        self.tableView.reloadData()
        
        IQKeyboardManager.sharedManager().enable = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(commentReceived),
                                               name: NSNotification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(CommentFragmentController.keyboardWillShow(_:)), name:NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CommentFragmentController.keyboardWillHide(_:)), name:NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CommentFragmentController.keyboardWillChange(_:)), name:NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CommentFragmentController.keyboardWillChange(_:)), name:NSNotification.Name.UITextInputCurrentInputModeDidChange, object:nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    @objc func commentReceived(_ notification: Notification) {
        if let wmcDict = notification.userInfo?["wmc"] as? [String : Any],
            let rawquestionId = wmcDict["question-id"] as? Int,
            let action = wmcDict["action"] as? String {
            
            if self.questionId?.rawId() == rawquestionId && action == "new comment" {
                AudioServicesPlaySystemSound(self.receivedSoundID)
                
                reload(scrollToEnd: false)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "Comments")
        tracker?.send((GAIDictionaryBuilder.createScreenView().build() as NSDictionary) as! [AnyHashable: Any])
        
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        
        if question != nil && self.comments == nil {
            self.passQuestion(question!)
        }
        
        makeCommentsSeen()
        
        myScrollToEnd()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        keyboardHide()
        
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
        
        NotificationCenter.default.removeObserver(self, name:NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name:NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name:NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.removeObserver(self, name:NSNotification.Name.UITextInputCurrentInputModeDidChange, object:nil)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        IQKeyboardManager.sharedManager().enable = true
    }
    
    static let stickerIDs = ["HappySmiley", "ToothSmiley", "FeelingBadSmiley", "SadSmiley",
                             "MischievousSmiley", "AngrySmiley", "FreezingSmiley", "InLoveSmiley",
                             "ThumbsdownSmiley", "WeiniSmiley", "HungrySmiley", "TooLateSmiley",
                             "BlauesAugeSmiley", "PokerSmiley", "BeerSmiley", "GamerSmiley",
                             "DrivingSmiley", "StreberSmiley", "KissSmiley", "MusicSmiley",
                             "NormalSmiley", "PopcornSmiley", "PunkSmiley", "SmileysInLove",
                             "SmokeySmiley", "SorrySmiley", "SportSmiley", "StonedSmiley",
                             "SurprisedSmiley", "ThinkingSmiley", "VomitSmiley", "JerseySmiley",
                             "Beer", "Bla_Bla_Bla", "Coffee", "OKAY", "Ouch", "Sorry", "WTF"]
    lazy var stickerAssets = stickerIDs.map({UIImage(named: $0)!})
    
    @IBAction func attachPressed(_ sender: AnyObject) {
        let alert = StickerSheetController(title: NSLocalizedString("pick_image_source", comment:""), stickerAssets: stickerAssets, stickerHandler: {sticker in
            
            let tempComment = self.send(text: nil, photo: sticker, isSticker: true)
            self.comments?.append(tempComment)
            self.tableView.reloadData()
            self.myScrollToEnd()
            
        })
        
        alert.addAction(ImagePickerAction(title: NSLocalizedString("pick_image_from_photo", comment: ""), handler: { alertAction in
            self.imagePicker.allowsEditing = false
            self.imagePicker.sourceType = .camera
            
            self.isReloadSuspended = true
            self.present(self.imagePicker, animated: true, completion: nil)
        }))
        
        alert.addAction(ImagePickerAction(title: NSLocalizedString("pick_image_from_gallery", comment: ""), handler: { alertAction in
            self.imagePicker.allowsEditing = false
            self.imagePicker.sourceType = .photoLibrary
            
            self.isReloadSuspended = true
            self.present(self.imagePicker, animated: true, completion: nil)
        }))
        
        //        alert.addAction(UIAlertAction(title: NSLocalizedString("pick_sticker", comment: ""), style: .default){ alertAction in
        //
        //        })
        
        alert.addAction(ImagePickerAction(cancelTitle: NSLocalizedString("cancel",comment:"")))
        
        alert.popoverPresentationController?.sourceView = sender as? UIView
        
        present(alert, animated: true, completion: nil)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if(text == "\n") {
            sendPressed(textView)
            return false;
        }
        return true;
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let rows:CGFloat = round((textView.contentSize.height - textView.textContainerInset.top - textView.textContainerInset.bottom) / textView.font!.lineHeight )
        if(rows <= 4){
            //            textView.sizeToFit()
        }
    }
    
    var ignoreKeyboard = false
    
    static var tempCommentCounter = -1
    static var tempCommentDone = Set<Int>()
    
    func send(text: String?, photo: UIImage?, isSticker:Bool = false) -> Comment {
        var tempComment: Comment?
        if let questionId = self.questionId {
            tempComment = Comment.sendComment(questionId, text: text, photo: photo, sticker: isSticker ? 1 : 0) { (comment, error) in
                if let error = error {
                    let alertController = UIAlertController(title: NSLocalizedString("error_server_down", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                } else if comment != nil {
                    Adjust.trackEvent(ADJEvent(eventToken: "agcd01"))
                    
                    if photo != nil {
                        //                        self.imageCache.setObject(photo, forKey: comment.id)
                        Adjust.trackEvent(ADJEvent(eventToken: "8z0y91"))
                    }
                    
                    AudioServicesPlaySystemSound(self.sentSoundID)
                }
                
                self.isReloadSuspended = false
                self.reload(scrollToEnd: true, ignoreCache: true)
            }
        }
        return tempComment!
    }
    
    @IBAction func sendPressed(_ sender: AnyObject) {
        ignoreKeyboard = true
        commentField.resignFirstResponder()
        commentField.becomeFirstResponder()
        ignoreKeyboard = false
        
        let text = commentField.text.trim()
        if text.characters.count > 0 {
            let tempComment = send(text: text, photo: nil)
            self.imageCache.removeObject(forKey: tempComment.id as AnyObject)
            self.comments?.append(tempComment)
            tableView.reloadData()
            self.myScrollToEnd()
        }
        
        self.commentField.text = ""
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerEditedImage] as? UIImage ?? info[UIImagePickerControllerOriginalImage] as? UIImage{
            let tempComment = self.send(text: nil, photo: pickedImage)
            //            self.imageCache.setObject(pickedImage, forKey: tempComment.id)
            self.comments?.append(tempComment)
            tableView.reloadData()
            self.myScrollToEnd()
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
        self.isReloadSuspended = false
        self.reload(scrollToEnd: false)
    }
    
    func makeCommentsSeen() {
        if UIApplication.shared.applicationState != .active {
            return
        }
        
        if let parentViewController = self.parent as? UITabBarController {
            if parentViewController.selectedViewController == self {
                if let questionId = self.questionId {
                    Question.makeCommentsSeen(questionId: questionId) { (madeSomeSeen, error) in
                        if error == nil && madeSomeSeen?.count > 0 {
                            if let parentViewController = self.parent as? UITabBarController {
                                parentViewController.tabBar.items![2].badgeValue = nil
                            }
                            
                            NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
                        }
                    }
                }
            }
        }
    }
    
    // Table view stuff
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 {
            if let followupComments = self.followupComments {
                return followupComments.count
            }
        } else {
            if let comments = self.comments {
                return comments.count + 1
            }
        }
        return 0
    }
    
    func cellForComment(_ comment: Comment) -> UITableViewCellWithObjectId {
        let cell = tableView.dequeueReusableCell(withIdentifier: comment.userId.rawId() == GlobalQuestionData.user_id ? "commentSelfCell" : "commentOtherCell") as! UITableViewCellWithObjectId
        
        let tempCommentId = "comments/-2"
        
        if cell.objectId == comment.id && comment.id != tempCommentId {
            return cell // already configured as comments are immutable
        }
        
        cell.objectId = comment.id
        
        cell.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI))
        
        cell.selectionStyle = .none
        
        let background = cell.viewWithTag(104) as? UIImageView
        if comment.isSticker {
            background?.image = nil
        } else if(comment.userId.rawId() == GlobalQuestionData.user_id){
            background?.image = selfBubble!
        } else{
            background?.image = otherBubble!
        }
        
        let commentTextLabel = cell.viewWithTag(101) as! TTTAttributedLabel
        commentTextLabel.enabledTextCheckingTypes = NSTextCheckingResult.CheckingType.link.rawValue
        commentTextLabel.linkAttributes = [kCTForegroundColorAttributeName as AnyHashable : UIColor.blue.cgColor,kCTUnderlineStyleAttributeName as AnyHashable : NSNumber(value: true as Bool)]
        commentTextLabel.activeLinkAttributes = [NSForegroundColorAttributeName : UIColor.purple]
        commentTextLabel.delegate = self
        
        commentTextLabel.text = comment.text
        commentTextLabel.font = UIFont.systemFont(ofSize: 16)
        commentTextLabel.setNeedsLayout()
        commentTextLabel.layoutIfNeeded()
        //        commentTextLabel.sizeToFit()
        
        let dateText = cell.viewWithTag(103) as? UILabel
//        if(question!.isPublic){
//            dateText?.text = ""
//        } else {
            let formatter = Date.WMCDateformatter.copy() as! DateFormatter
            if(NSCalendar.current.isDateInToday(comment.created)){
                formatter.dateStyle = .none
            }
            dateText?.text = formatter.string(from: comment.created)
//        }
        
        let cachedImage = self.imageCache.object(forKey: comment.id as AnyObject) as? UIImage
        let indicator = cell.viewWithTag(115) as! UIActivityIndicatorView
        
        if comment.id == tempCommentId || (comment.photoId != nil && cachedImage == nil) {
            indicator.isHidden = false
            indicator.startAnimating()
        } else {
            indicator.isHidden = true
            indicator.stopAnimating()
        }
        
        let imageView = cell.viewWithTag(105) as! UIImageView
        commentTextLabel.isHidden = comment.photoId != nil
        imageView.isHidden = comment.photoId == nil
        
        if comment.photoId != nil {
            imageView.image = cachedImage
            
            if imageView.gestureRecognizers == nil || imageView.gestureRecognizers?.count == 0 {
                let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(self.imageTapped(_:)))
                imageView.isUserInteractionEnabled = true
                imageView.addGestureRecognizer(tapGestureRecognizer)
            }
            
            imageView.layer.cornerRadius = comment.isSticker ? 20 : 0
            //            imageView.contentMode = comment.isSticker ? .scaleAspectFit : .scaleAspectFill
            for constraint in imageView.constraints {
                if constraint.identifier == "imageHeight" {
                    constraint.constant = comment.isSticker ? 96 : 240
                } else if constraint.identifier == "imageWidth" {
                    constraint.constant = comment.isSticker ? 128 : 210
                }
            }
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            
            if(cachedImage == nil){
                DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
                    comment.photo({ (photo, error) in
                        if cell.objectId != comment.id {
                            return
                        }
                        
                        DispatchQueue.main.async(execute: {
                            if let photo = photo {
                                imageView.image = photo
                                indicator.isHidden = true
                                indicator.stopAnimating()
                                
                                self.imageCache.setObject(photo, forKey: comment.id as AnyObject)
                                
                                //                                imageView.contentMode = comment.isSticker ? .scaleAspectFit : .scaleAspectFill
                                for constraint in imageView.constraints{
                                    if(constraint.identifier == "imageHeight"){
                                        let height = comment.isSticker ? 96 : CGFloat(240)
                                        constraint.constant = height
                                    } else if constraint.identifier == "imageWidth" {
                                        constraint.constant = comment.isSticker ? 128 : 210
                                    }
                                }
                                
                                cell.setNeedsLayout()
                                cell.layoutIfNeeded()
                                self.tableView.reloadData()
                            }
                        })
                    })
                })
            } else{
                indicator.isHidden = true
                indicator.stopAnimating()
            }
        } else {
            imageView.image = nil
            
            for constraint in imageView.constraints{
                if(constraint.identifier == "imageHeight"){
                    constraint.constant = 0
                }
            }
            
            indicator.isHidden = true
            indicator.stopAnimating()
        }
        
        // blocking should be done server side if needed, right?
        //            if(comment.user?.relation == .BLACKLIST){
        //                commentTextLabel.text = NSLocalizedString("comment_blocked", comment: "")
        //                imageView.image = nil
        //            } else if comment.user == nil {
        //                let isBlocked = DatabaseOpenHelper.instance.selectFirst("SELECT CONTACT_ID FROM contacts WHERE USER_ID=? AND CONTACT_ID=? AND relation=-1", arguments: [GlobalQuestionData.user_id, comment.creator_id])
        //                if(isBlocked != nil){
        //                    commentTextLabel.text = NSLocalizedString("comment_blocked", comment: "")
        //                    imageView.image = nil
        //                }
        //            }
        
        let creatorText = cell.viewWithTag(102) as! UILabel
        creatorText.text = ""
        
        if let creatorImageView = cell.viewWithTag(110) as? UIImageView {
            creatorImageView.image = nil
            for constraint in creatorImageView.constraints{
                if(constraint.identifier == "creatorImageConstant"){
//                    constraint.constant = question!.isPublic ? 0 : 32
                }
            }
            
            if creatorImageView.gestureRecognizers == nil || creatorImageView.gestureRecognizers?.count == 0 {
                let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(self.creatorPicTapped(_:)))
                creatorImageView.isUserInteractionEnabled = true
                creatorImageView.addGestureRecognizer(tapGestureRecognizer)
                creatorImageView.layer.borderWidth = 1.0
                creatorImageView.layer.masksToBounds = false
                creatorImageView.layer.borderColor = UIColor.white.cgColor
                creatorImageView.layer.cornerRadius = (creatorImageView.frame.size.width)/2
                creatorImageView.clipsToBounds = true
            }
        }
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
            User.fetchUsers(userId: comment.userId) { (users, error) in
                if cell.objectId != comment.id {
                    return
                }
                
                DispatchQueue.main.async(execute: {
                    if let user = users?.first {
                        let creatorText = cell.viewWithTag(102) as! UILabel
                        
                        if !self.question!.isPublic {
                            creatorText.text = user.username
                        }
                            if let creatorImageView = cell.viewWithTag(110) as? UIImageView {
                                if user.photoId != nil && user.picture == nil && !self.question!.isPublic {
                                    user.fetchPhoto({ (photo, error) in
                                        if cell.objectId != comment.id {
                                            return
                                        }
                                        creatorImageView.image = photo
                                    })
                                } else if user.picture != nil && !self.question!.isPublic {
                                    creatorImageView.image = user.picture
                                } else{
                                    creatorImageView.image = #imageLiteral(resourceName: "ic_launcher")
                                }
                                
                            }
//                        } else {
//                            creatorText.text = ""
//                        }
                    }
                })
            }
        })
        
        //        commentTextLabel.sizeToFit()
        
        return cell
    }
    
    var isNeedingScrollToEnd: Bool = false
    
    var imageHeightConstraints = [Int:NSLayoutConstraint]()
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = tableView.numberOfSections - 1 - indexPath.section
        let realIndex = IndexPath(row: tableView.numberOfRows(inSection: indexPath.section) - 1 - indexPath.row, section: section)
        
        if realIndex.section == 0 {
            let comment = self.followupComments![realIndex.row]
            
            if comment.leave || comment.stop || comment.addedChoice != nil || comment.invitedMember != nil || comment.isCreationNotice {
                return self.cellForControlMessage(comment: comment)
            } else {
                return self.cellForComment(comment)
            }
        } else if realIndex.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "commentInfoCell")!
            
            cell.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI))
            
            let qTitle = cell.viewWithTag(105) as? UILabel
            
            if question!.isChatOnly {
                User.fetchUsers(questionId: question!.id) { (users, error) in
                    if let otherUser = users?.filter({$0.user_id != GlobalQuestionData.user_id}).first, users?.count == 2 {
                        qTitle?.text = otherUser.username
                    } else {
                        qTitle?.text = self.questionText
                    }
                }
            } else {
                qTitle?.text = questionText
            }
            
            qTitle?.isHidden = questionText == nil
            qTitle?.clipsToBounds = true
            
            cell.selectionStyle = .default
            
            return cell
        } else {
            let index = realIndex.row - 1
            let comment = self.comments![index]
            if comment.leave || comment.stop || comment.addedChoice != nil || comment.invitedMember != nil || comment.isCreationNotice {
                return self.cellForControlMessage(comment: comment)
            } else {
                return self.cellForComment(comment)
            }
        }
        
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = tableView.numberOfSections - 1 - indexPath.section
        let realIndex = IndexPath(row: tableView.numberOfRows(inSection: indexPath.section) - 1 - indexPath.row, section: section)
        
        if question!.isChatOnly && realIndex.section == 1 && realIndex.row == 0 {
            chatInfoClicked()
            
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let pos = touch.location(in: navigationController?.navigationBar)
        
        return !(touch.view is UIControl) && pos.x > 100 && self.isViewLoaded && self.view.window != nil
    }
    
    func chatInfoClicked(){
        if question!.isChatOnly {
            let infoController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "UserInfoController") as! UserInfoController
            infoController.set(question: question!)
            
            let height = NSLayoutConstraint(item: infoController.view, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: self.view.frame.height * 0.50)
            infoController.view.addConstraint(height);
            
            let userAlert = UIAlertController(title: "", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            userAlert.setValue(infoController, forKey: "contentViewController")
            userAlert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .default, handler: nil))
            
            self.present(userAlert, animated: true, completion: nil)
        }
    }
    
    func cellForControlMessage(comment: Comment) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "commentControlMessageCell")!
        
        cell.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI))
        cell.selectionStyle = .none
        
        let controlNotice = cell.viewWithTag(105) as! UILabel
        controlNotice.clipsToBounds = true
        controlNotice.layer.borderWidth = 0.0
        controlNotice.layer.masksToBounds = false
        controlNotice.layer.cornerRadius = 12
        
        let creatorPic = cell.viewWithTag(106) as! UIImageView
    //    if !question!.isPublic {
        let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(self.creatorPicTapped(_:)))
        creatorPic.isUserInteractionEnabled = true
        creatorPic.addGestureRecognizer(tapGestureRecognizer)
        creatorPic.image = nil
        creatorPic.layer.borderWidth = 0.0
        creatorPic.layer.masksToBounds = false
        creatorPic.layer.cornerRadius = 16
        creatorPic.clipsToBounds = true
      //  }
        if let invitee = comment.invitedMember {
            User.fetchUsers(userId: "users/\(invitee)", completion: { (users, error) in
                if let user = users?.first {
                    if user.photoId != nil && user.picture == nil {
                        user.fetchPhoto({ (photo, error) in
                            creatorPic.image = photo
                        })
                    }
                    
                    controlNotice.text = NSString(format: NSLocalizedString("join_notice", comment: "") as NSString, user.username) as String
                    
                    creatorPic.image = user.picture
                }
            })
        } else{
            User.fetchUsers(userId: comment.userId) { (users, error) in
                if let user = users?.first {
                    if user.photoId != nil && user.picture == nil {
                        user.fetchPhoto({ (photo, error) in
                            creatorPic.image = photo
                        })
                    }
                    
                    /// Here som change:..... This part is in progress
                    
                    
                    if(comment.leave && !self.question!.isChatOnly){
                        controlNotice.text = NSString(format: NSLocalizedString("leave_notice", comment: "") as NSString, user.username) as String
                       
                        
                    } else if(comment.leave && self.question!.isChatOnly){
                        controlNotice.text = NSString(format: NSLocalizedString("chat_leave_notice", comment: "") as NSString, user.username) as String
                       
                    } else if (comment.stop){
                        controlNotice.text = NSString(format: NSLocalizedString("close_notice", comment: "") as NSString, self.question!.isPublic ? "Judge it!" : user.username) as String
                    } else if(comment.addedChoice != nil){
                        controlNotice.text = NSString(format: NSLocalizedString("choice_notice", comment: "") as NSString, user.username) as String
                    } else if(comment.isCreationNotice && !self.question!.isChatOnly){
                        controlNotice.text = NSString(format: NSLocalizedString("create_notice", comment: "") as NSString, self.question!.isPublic ? "Judge it!" : user.username) as String
                    } else if(comment.isCreationNotice && self.question!.isChatOnly){
                        controlNotice.text = NSString(format: NSLocalizedString("chat_create_notice", comment: "") as NSString, self.question!.isPublic ? "Judge it!" : user.username) as String
                    }
                    print("controlNotice = \(String(format: "%@", controlNotice.text!))")
                    let textRect: CGRect =  (controlNotice.text?.boundingRect(with: CGSize(width:cell.contentView.frame.size.width - 40, height: 500), options: .usesLineFragmentOrigin, attributes: [NSFontAttributeName: UIFont.systemFont(ofSize:14.0)], context: nil))!
                    controlNotice.frame = CGRect(x: cell.contentView.bounds.midX - controlNotice.bounds.midX, y: controlNotice.frame.origin.y, width: (textRect.width), height: CGFloat(controlNotice.frame.size.height))
                    creatorPic.image = user.picture
                }
            }
        }
        
        return cell
    }
    
    func creatorPicTapped(_ sender: UITapGestureRecognizer) {
        let imageView = sender.view as! UIImageView
        
        let clickedCell = imageView.superview!.superview as! UITableViewCell
        if let indexPath = self.tableView?.indexPath(for: clickedCell) {
            let section = tableView.numberOfSections - 1 - indexPath.section
            let realIndex = IndexPath(row: tableView.numberOfRows(inSection: indexPath.section) - 1 - indexPath.row, section: section)
            
            if let comment = self.comments![safe: realIndex.row - 1] {
                
                User.fetchUsers(userId: comment.userId, alsoCached: false) { (users, error) in
                    if let user = users?.first {
                        let infoController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "UserInfoController") as! UserInfoController
                        infoController.set(user: user)
                        
                        let userAlert = UIAlertController(title: "", message: nil, preferredStyle: UIAlertControllerStyle.alert)
                        userAlert.setValue(infoController, forKey: "contentViewController")
                        userAlert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .default, handler: { alertAction in
                            self.reload(scrollToEnd: false)
                        }))
                        if (self.question?.isPublic)! {
                        
                        } else {
                            self.present(userAlert, animated: true, completion: nil)
                        }
                        
                    }
                }
            }
        }
    }
    
    func attributedLabel(_ label: TTTAttributedLabel!, didSelectLinkWith url: URL!) {
        UIApplication.shared.openURL(url)
    }
    
    func imageTapped(_ sender: UITapGestureRecognizer){
        let imageView = sender.view as! UIImageView
        
        let clickedCell = imageView.superview!.superview!.superview as! UITableViewCell
        if let indexPath = self.tableView?.indexPath(for: clickedCell){
            let section = tableView.numberOfSections - 1 - indexPath.section
            let realIndex = IndexPath(row: tableView.numberOfRows(inSection: indexPath.section) - 1 - indexPath.row, section: section)
            
            if let comment = self.comments![safe: realIndex.row - 1],
                let image = imageView.image{
                let image = ChoiceFragmentController.NYTChoicePicture(image: image, imageData: UIImagePNGRepresentation(image), attributedCaptionTitle: NSAttributedString(string: comment.text ?? "", attributes: [NSForegroundColorAttributeName: UIColor.white]))
                
                let photoViewController = NYTPhotosViewController(photos: [image])
                self.present(photoViewController, animated: true, completion: {})
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        self.imageCache.removeAllObjects()
        self.reload(scrollToEnd: false)
    }
    
    // Actually scrolls to "begin", since tableview populates from bottom
    func myScrollToEnd() {
        // hack to avoid table cell update issues:
        
        /*
         var offsetBefore, offsetAfter: CGPoint
         repeat {
         offsetBefore = tableView.contentOffset
         tableView.scrollToEnd(false);
         offsetAfter = tableView.contentOffset
         } while offsetBefore.y != offsetAfter.y
         */
        
        //        if tableView.contentOffset.y < (tableView.contentSize.height - tableView.frame.size.height) {
        // only if scrolling is needed:
        let dispatchTime: DispatchTime = DispatchTime.now() + Double(Int64(0.225 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
            if(self.tableView.numberOfSections > 0 && self.tableView.numberOfRows(inSection: 0) > 0){
                self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .bottom, animated: false)
            }
        })
        //        }
    }
    
}
