//
//  ChoiceFragmentController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 06/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation
import UIKit
import Adjust
import NYTPhotoViewer
import TTTAttributedLabel
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


class ChoiceFragmentController : UIViewController, UITableViewDataSource, UITableViewDelegate, QuestionFragment, TTTAttributedLabelDelegate {
    
    var choices: [Choice]?
    var isTextQuestion: Bool = true
    var question:Question?
    
    @IBOutlet var tableView: UITableView!
    
    // map choice id -> rating value
    fileprivate var ratingChanges = [String : Int]()
    
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var discardButton: UIButton!
    
    @IBOutlet var backgroundImage: UIImageView!
    
    func passQuestion(_ question:Question) {
        self.question = question
        self.reload()
    }
    
    func reload() {
        // Force view loading:
        if self.view != nil {
            if let question = self.question {
                DispatchQueue.global(priority: .default).async(execute: {
                    Choice.fetchChoices(question: question, choiceId: nil) { (choices, error) in
                        if let choices = choices {
                            let isChanged = self.choices == nil || self.choices! != choices
                            
                            self.choices = choices
                            self.isTextQuestion = true
                            
                            for choice in choices {
                                if choice.photoId?.characters.count > 0 {
                                    self.isTextQuestion = false
                                    break
                                }
                            }
                            
                            DispatchQueue.main.async {
                                self.tableView.estimatedRowHeight = self.isTextQuestion ? 50 : 175
                                self.tableView.separatorStyle = self.isTextQuestion ? .none : .singleLine
                                if isChanged {
                                    self.tableView.reloadData()
                                }
                            }
                        }
                    }
                })
            }
            self.makeChoicesSeen()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad(){
        super.viewDidLoad()
        
        self.automaticallyAdjustsScrollViewInsets = false
        
        saveButton.layer.cornerRadius = saveButton.frame.size.height/2
        //        saveButton.layer.masksToBounds = false
        saveButton.clipsToBounds = true
        discardButton.layer.cornerRadius = discardButton.frame.size.height/2
        //        discardButton.layer.masksToBounds = false
        discardButton.clipsToBounds = true
        
        saveButton.isHidden = true
        discardButton.isHidden = true
        
        saveButton.addTarget(self, action: #selector(ChoiceFragmentController.save), for: .touchUpInside)
        discardButton.addTarget(self, action: #selector(ChoiceFragmentController.discard), for: .touchUpInside)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        let prefs = UserDefaults.standard
        if let path = prefs.object(forKey: "wallpaper_path") as? String{
            if let dir : NSString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first as NSString?{
                let relativePath = dir.appendingPathComponent(path)
                backgroundImage.image = UIImage(contentsOfFile: relativePath)
            }
            print("Loaded background image, path \(path), but image nil \(backgroundImage.image == nil)")
        } else if let color = prefs.colorForKey("wallpaper_color"){
            backgroundImage.backgroundColor = color
        }
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
        saveButton.isHidden = true
        discardButton.isHidden = true
        
        //        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.makeChoicesSeen()
    }
    override func viewWillDisappear(_ animated: Bool) {
        ratingChanges.removeAll()
    }
    
    func applicationDidBecomeActive() {
        self.makeChoicesSeen()
    }
    
    func makeChoicesSeen() {
        if UIApplication.shared.applicationState != .active {
            return
        }
        
        if let parentViewController = self.parent as? UITabBarController {
            if parentViewController.selectedViewController == self {
                if let questionId = self.question?.id {
                    Question.makeChoicesSeen(questionId: questionId) { (madeSomeSeen, error) in
                        if error == nil && madeSomeSeen?.count > 0 {
                            if let parentViewController = self.parent as? UITabBarController {
                                parentViewController.tabBar.items![0].badgeValue = nil
                            }
                            
                            NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
                        }
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        if let choices = self.choices {
            return (self.isTextQuestion ? choices.count : (choices.count+1)/2) + 1
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "titlecell")!
            
            let titleLabel = cell.viewWithTag(105) as! UILabel
            titleLabel.text = question?.text
            
            let creatorPic = cell.viewWithTag(106) as! UIImageView
            creatorPic.layer.borderWidth = 1.0
            creatorPic.layer.masksToBounds = false
            creatorPic.layer.borderColor = UIColor.white.cgColor
            creatorPic.layer.cornerRadius = (creatorPic.frame.size.width)/2
            creatorPic.clipsToBounds = true
            
            if !question!.isPublic {
                let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(creatorPicTapped(_:)))
                creatorPic.isUserInteractionEnabled = true
                creatorPic.addGestureRecognizer(tapGestureRecognizer)
                
                DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
                    User.fetchUsers(questionId: self.question?.id ?? "", userId: self.question?.creatorId) { (users, error) in
                        if let user = users?.first {
                            if user.photoId != nil && user.picture == nil {
                                user.fetchPhoto({ (photo, error) in
                                    DispatchQueue.main.async(execute: {
                                        creatorPic.image = photo
                                    })
                                })
                            }
                        }
                    }
                })
            } else {
                let defaultIcon = UIImage(named: "LoginIcon")!
                creatorPic.image = defaultIcon
            }
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: self.isTextQuestion ? "textChoiceCell" : "choiceCell", for: indexPath)
            
            var rowChoices = [Choice]()
            let rowIndex = indexPath.row - 1
            
            if let firstChoice = self.choices![safe: 2*rowIndex], (!self.isTextQuestion){
                // Photo question. Show two photo choices in a row:
                rowChoices.append(firstChoice)
                let view = cell.viewWithTag(108)!
                if let additionalChoice = self.choices![safe: 2*rowIndex+1]{
                    rowChoices.append(additionalChoice)
                    view.isHidden = false
                } else{
                    view.isHidden = true
                }
            } else if let singleChoice = self.choices![safe: rowIndex] {
                // Text question. Show one text choice per row:
                rowChoices.append(singleChoice)
            }
            
            //            let leftView = cell.viewWithTag(99)
            //            leftView?.layer.borderWidth = 1
            //            leftView?.layer.borderColor = UIColor.gray.cgColor
            //            leftView?.layer.cornerRadius = 10
            //
            //            let rightView = cell.viewWithTag(108)
            //            rightView?.layer.borderWidth = 1
            //            rightView?.layer.borderColor = UIColor.gray.cgColor
            //            rightView?.layer.cornerRadius = 10
            
            for (index, choice) in rowChoices.enumerated() {
                let choiceLabel = cell.viewWithTag(100+4*index) as? TTTAttributedLabel
                
                choiceLabel?.textAlignment = self.isTextQuestion ? .left : .center
                choiceLabel?.enabledTextCheckingTypes = NSTextCheckingResult.CheckingType.link.rawValue
                choiceLabel?.linkAttributes = [kCTForegroundColorAttributeName as AnyHashable : UIColor.blue.cgColor,kCTUnderlineStyleAttributeName as AnyHashable : NSNumber(value: true as Bool)]
                choiceLabel?.activeLinkAttributes = [NSForegroundColorAttributeName : UIColor.purple]
                choiceLabel?.delegate = self
                choiceLabel?.text = choice.text.trim().length > 0 ? choice.text : "\(NSLocalizedString("choice_choice", comment: "")) \(2*rowIndex+index+1)"
                
                let downvoteButton = cell.viewWithTag(101+4*index) as! UIButton
                if downvoteButton.allTargets.count == 0 {
                    downvoteButton.addTarget(self, action: #selector(downvote(_:)), for: .touchUpInside)
                    downvoteButton.layer.cornerRadius = (downvoteButton.frame.size.height )/2
                    downvoteButton.clipsToBounds = true
                    downvoteButton.layer.borderWidth = 1.0
                    downvoteButton.layer.borderColor = UIColor.white.cgColor
                }
                
                let upvoteButton = cell.viewWithTag(102+4*index) as! UIButton
                if upvoteButton.allTargets.count == 0 {
                    upvoteButton.addTarget(self, action: #selector(upvote(_:)), for: .touchUpInside)
                    upvoteButton.layer.cornerRadius = (downvoteButton.frame.size.height )/2
                    upvoteButton.clipsToBounds = true
                    upvoteButton.layer.borderWidth = 1.0
                    upvoteButton.layer.borderColor = UIColor.white.cgColor
                }
                
                Rating.ratings(questionId: self.question!.id, choiceId: choice.id, raterId: "users/\(GlobalQuestionData.user_id)", completion: { (ratings, error) in
                    if error == nil {
                        var ratingValue: Int = 0
                        
                        if let changedRatingValue = self.ratingChanges[choice.id] {
                            ratingValue = changedRatingValue
                        } else if let rating = ratings?.first {
                            ratingValue = rating.rating
                        }
                        
                        if ratingValue == 1 {
                            upvoteButton.backgroundColor = UIColor.judgeItUpvoteColor
                            downvoteButton.backgroundColor = UIColor.clear
                        } else if ratingValue == -1 {
                            downvoteButton.backgroundColor = UIColor.judgeItDownvoteColor
                            upvoteButton.backgroundColor = UIColor.clear
                        } else {
                            upvoteButton.backgroundColor = UIColor.clear
                            downvoteButton.backgroundColor = UIColor.clear
                        }
                    }
                })
                
                if let choicePhotoImageView = cell.viewWithTag(103+4*index) as? UIImageView {
                    if choicePhotoImageView.gestureRecognizers == nil || choicePhotoImageView.gestureRecognizers?.count == 0 {
                        let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(self.imageTapped))
                        choicePhotoImageView.isUserInteractionEnabled = true
                        choicePhotoImageView.addGestureRecognizer(tapGestureRecognizer)
                        
                        choicePhotoImageView.layer.borderWidth = 1.0
                        choicePhotoImageView.layer.masksToBounds = false
                        choicePhotoImageView.layer.borderColor = UIColor.white.cgColor
                        choicePhotoImageView.layer.cornerRadius = 65
                        choicePhotoImageView.clipsToBounds = true
                    }
                    
                    choicePhotoImageView.image = choice.picture
                    if choice.photoId != nil {
                        if choice.picture == nil {
                            choice.photo({ (photo, error) in
                                if let photo = photo {
                                    //                                    choice.picture = photo
                                    choicePhotoImageView.image = photo
                                }
                            })
                        }
                    }
                }
            }
            
            return cell
        }
    }
    
    func creatorPicTapped(_ sender: UITapGestureRecognizer) {
        User.fetchUsers(questionId: self.question!.id, userId: self.question!.creatorId, alsoCached: false) { (users, error) in
            if let user = users?.first {
                let infoController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "UserInfoController") as! UserInfoController
                infoController.set(user: user)
                
                let userAlert = UIAlertController(title: "", message: nil, preferredStyle: UIAlertControllerStyle.alert)
                userAlert.setValue(infoController, forKey: "contentViewController")
                userAlert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .default, handler: { alertAction in
                }))
                
                self.present(userAlert, animated: true, completion: nil)
            }
        }
    }
    
    func choiceUrlTapped(_ sender: UITapGestureRecognizer){
        let titleView = sender.view as! UILabel
        
        let clickedCell = (titleView.superview!.superview as? UITableViewCell ?? titleView.superview!.superview!.superview!.superview as? UITableViewCell)!
        let indexPath = tableView.indexPath(for: clickedCell)
        var index = indexPath!.row - 1
        if(!self.isTextQuestion){
            index = 2*indexPath!.row + ((titleView.tag - 100)/4) - 1
        }
        
        if let choice = self.choices![safe: index],
            let url = choice.url() {
            UIApplication.shared.openURL(url as URL)
        }
    }
    
    func imageTapped(_ sender: UITapGestureRecognizer){
        let imageView = sender.view as! UIImageView
        
        let clickedCell = (imageView.superview!.superview as? UITableViewCell ?? imageView.superview!.superview!.superview!.superview as? UITableViewCell)!
        let indexPath = tableView.indexPath(for: clickedCell)
        
        var index = indexPath!.row - 1
        if !self.isTextQuestion {
            index = 2*index + ((imageView.tag - 100)/4)
        }
        let selectedChoice = self.choices![safe: index]
        
        if selectedChoice?.photoId != nil {
            let photo_dispatchGroup = DispatchGroup()
            var selectedImage:NYTChoicePicture?
            var nytTuples = [(Int,NYTChoicePicture)]()
            for choice in self.choices!.filter({$0.photoId != nil}){
                photo_dispatchGroup.enter()
                choice.photo({image, error in
                    if let image = image {
                        let nytImage = NYTChoicePicture(image: image, imageData: UIImagePNGRepresentation(image),
                                                        attributedCaptionTitle: NSAttributedString(string: choice.text, attributes: [NSForegroundColorAttributeName: UIColor.white]))
                        
                        nytTuples.append((self.choices!.index(of: choice)!, nytImage))
                        if(choice.id == selectedChoice!.id){
                            selectedImage = nytImage
                        }
                    }
                    photo_dispatchGroup.leave()
                })
            }
            photo_dispatchGroup.notify(queue: DispatchQueue.main, execute: {
                let nytImages = nytTuples.sorted(by: {$0.0.0 < $0.1.0}).map({$0.1})
                
                let photoViewController = NYTPhotosViewController(photos: nytImages, initialPhoto: selectedImage!)
                self.present(photoViewController, animated: true, completion: nil)
            })
        }
    }
    
    func attributedLabel(_ label: TTTAttributedLabel!, didSelectLinkWith url: URL!) {
        UIApplication.shared.openURL(url)
    }
    
    func rate(choice: Choice, newRatingValue: Int) {
        if self.question!.isRandomVoting {
            var participantDicts = [[String: Any]]()
            var participantDictionary = [String: Any]()
            participantDictionary["participant-id"] = "users/\(GlobalQuestionData.user_id)"
            participantDictionary["muted?"] = false
            participantDicts.append(participantDictionary)
            
            User.addParticipants(questionId: self.question!.id, participantsDictionaries: participantDicts, completion: { (some, error) in
                if error == nil {
                    self.question!.isRandomVoting = false
                    
                    self.sendRating(choice: choice, newRatingValue: newRatingValue)
                }
            })
        } else {
            sendRating(choice: choice, newRatingValue: newRatingValue)
        }
    }
    
    func sendRating(choice: Choice, newRatingValue: Int){
        Rating.ratings(questionId: self.question!.id, choiceId: choice.id, raterId: "users/\(GlobalQuestionData.user_id)", alsoCached: false) { (ratings, error) in
            if error == nil {
                let userRating = ratings?.first
                if (self.ratingChanges[choice.id] ?? userRating?.rating ?? nil) != newRatingValue {
                    self.ratingChanges.updateValue(newRatingValue, forKey: choice.id)
                    self.tableView.reloadData()
                    
                    self.saveButton.isHidden = false
                    self.discardButton.isHidden = false
                }
            }
        }
    }
    
    func choiceFor(voteButton: UIButton) -> Choice {
        let clickedCell = (voteButton.superview!.superview as? UITableViewCell ?? voteButton.superview!.superview!.superview!.superview as? UITableViewCell)!
        let indexPath = self.tableView.indexPath(for: clickedCell)!
        var index = indexPath.row - 1
        if !self.isTextQuestion {
            index = 2*index + ((voteButton.tag - 100)/4)
        }
        
        return self.choices![index]
    }
    
    @IBAction func downvote(_ sender:UIButton){
        if(self.question?.isClosed ?? false){
            User.fetchUsers(questionId: self.question!.id, userId: self.question!.creatorId, completion: { (users, error) in
                if let user = users?.first {
                    let closeNotice = NSString(format: NSLocalizedString("close_notice", comment: "") as NSString, user.username) as String
                    let alertController = UIAlertController(title: nil, message: closeNotice, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
            })
        } else{
            self.rate(choice: choiceFor(voteButton: sender), newRatingValue: -1)
        }
    }
    
    @IBAction func upvote(_ sender:UIButton){
        if(self.question?.isClosed ?? false){
            User.fetchUsers(questionId: self.question!.id, userId: self.question!.creatorId, completion: { (users, error) in
                if let user = users?.first {
                    let closeNotice = NSString(format: NSLocalizedString("close_notice", comment: "") as NSString, user.username) as String
                    let alertController = UIAlertController(title: nil, message: closeNotice, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
            })
        } else{
            self.rate(choice: choiceFor(voteButton: sender), newRatingValue: 1)
        }
    }
    
    @IBAction func discard(){
        saveButton.isHidden = true
        discardButton.isHidden = true
        
        ratingChanges.removeAll()
        tableView.reloadData()
    }
    
    @IBAction func save() {
        saveButton.isHidden = true
        discardButton.isHidden = true
        
        var ratingDicts = [[String : Any]]()
        for (choiceId, ratingValue) in self.ratingChanges {
            let ratingDict: [String : Any] = ["choice-id" : choiceId,
                                              "rating" : ratingValue]
            ratingDicts.append(ratingDict)
        }
        
        // Make sure user is part of voting
        if(question!.isRandomVoting){
            var participantDicts = [[String: Any]]()
            var participantDictionary = [String: Any]()
            participantDictionary["participant-id"] = "users/\(GlobalQuestionData.user_id)"
            participantDictionary["muted?"] = false
            participantDicts.append(participantDictionary)
            
            User.addParticipants(questionId: self.question!.id, participantsDictionaries: participantDicts, completion: { (some, error) in
                if error == nil {
                    Rating.addRatings(questionId: self.question!.id, ratingDictionaries: ratingDicts, completion: self.saveSendRatings)
                }
            })
            
        } else {
            Rating.addRatings(questionId: self.question!.id, ratingDictionaries: ratingDicts, completion: saveSendRatings)
        }
    }
    
    func saveSendRatings(error: NSError?){
        self.ratingChanges.removeAll()
        
        if let error = error {
            self.saveButton.isHidden = false
            self.discardButton.isHidden = false
            let alertController = UIAlertController(title: "Network Error", message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: (NSLocalizedString("ok", comment: "OK")), style: .default, handler: nil))
            
            self.present(alertController, animated: true, completion: nil)
        }
        (self.tabBarController as? VotingViewController)?.selectedIndex = VotingViewController.TabTag.results.rawValue
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil, userInfo: ["noCache": false])
    }
    
    class NYTChoicePicture : NSObject, NYTPhoto {
        
        var image: UIImage?
        var imageData: Data?
        let placeholderImage:UIImage? = UIImage(imageLiteralResourceName: "ic_remove_user")
        let attributedCaptionTitle: NSAttributedString?
        let attributedCaptionSummary: NSAttributedString? = NSAttributedString(string: "", attributes: [NSForegroundColorAttributeName: UIColor.gray])
        let attributedCaptionCredit: NSAttributedString? = NSAttributedString(string: "", attributes: [NSForegroundColorAttributeName: UIColor.darkGray])
        
        init(image: UIImage? = nil, imageData: Data? = nil, attributedCaptionTitle: NSAttributedString) {
            self.image = image
            self.imageData = imageData
            self.attributedCaptionTitle = attributedCaptionTitle
            super.init()
        }
        
    }
    
}
