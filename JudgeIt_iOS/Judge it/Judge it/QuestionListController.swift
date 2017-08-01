//
//  File.swift
//  Judge it
//
//  Created by Daniel Thevessen on 17/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import UIKit
import Adjust
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


class QuestionListController: NSObject, UITableViewDataSource {
    
    var questionList:[Question]
    fileprivate let user_id:Int
    fileprivate let login_token:String
    fileprivate let parent:VotingListViewController
    
    let textThumbnailCache = NSCache<AnyObject, AnyObject>()
    let imageThumbnailCache = NSCache<AnyObject, AnyObject>()
    
    @IBOutlet var helpUpArrowImageView: UIImageView!
    @IBOutlet var helpDownArrowImageView: UIImageView!
    @IBOutlet var upperHelpViewWrapperView: UIView!
    @IBOutlet var lowerHelpViewWrapperView: UIView!
    
    init(parent:VotingListViewController, questionList: [Question]){
        self.questionList = questionList
        user_id = GlobalQuestionData.user_id
        login_token = GlobalQuestionData.login_token
        self.parent = parent
        
        super.init()
    }
    
    func updateQuestions(_ newQuestions: [Question]) -> Bool {
        if !newQuestions.elementsEqual(self.questionList, by: ==) {
            self.questionList = newQuestions
            self.textThumbnailCache.removeAllObjects()
            self.imageThumbnailCache.removeAllObjects()
            return true
        } else {
            return false
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableView.separatorStyle = UITableViewCellSeparatorStyle.singleLine
        
        //        if questionList.count == 0 {
        //            let helpView = UINib(nibName: "DashboardHelp", bundle: nil).instantiate(withOwner: self, options: nil)[0] as! UIView
        //
        //            let upImage = UIImage(named: "ic_help_arrow");
        //            let tintableUpImage = upImage?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        //            helpUpArrowImageView.image = tintableUpImage
        //            helpUpArrowImageView.transform = CGAffineTransform(scaleX: -1.0, y: 1.0);
        //
        //            let downImage = UIImage(named: "ic_help_arrow_down");
        //            let tintableDownImage = downImage?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        //            helpDownArrowImageView.image = tintableDownImage
        //            helpDownArrowImageView.transform = CGAffineTransform(scaleX: -1.0, y: 1.0);
        //
        //            upperHelpViewWrapperView.layer.cornerRadius = 5
        //            upperHelpViewWrapperView.clipsToBounds = true
        //            lowerHelpViewWrapperView.layer.cornerRadius = 5
        //            lowerHelpViewWrapperView.clipsToBounds = true
        //
        //            tableView.backgroundView = helpView
        //            tableView.separatorStyle = UITableViewCellSeparatorStyle.none
        //        } else {
        //            tableView.backgroundView = nil
        //            tableView.backgroundColor = UIColor.white
        //        }
        
        return self.questionList.count
        //        return min(questionList.count, limit) + (limit < questionList.count ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let question = questionList[safe: indexPath.row]!
        let cell = tableView.dequeueReusableCell(withIdentifier: "questionCell") as! UITableViewCellWithObjectId
        cell.objectId = question.id
        
        tableView.backgroundView = nil
        
        let iconImageView = cell.viewWithTag(100) as! UIImageView
        iconImageView.image = nil
        iconImageView.layer.borderWidth = 2.0
        iconImageView.layer.masksToBounds = false
        iconImageView.layer.borderColor = UIColor.white.cgColor
        iconImageView.layer.cornerRadius = (iconImageView.frame.size.width)/2
        iconImageView.clipsToBounds = true

        let textQuestionInfoLabel = cell.viewWithTag(109) as! UILabel
        
        Choice.fetchChoices(question: question, choiceId: nil) { (choices, error) in
            if question.id != cell.objectId {
                return
            }
            
            var isTextQuestion = true
            
            if let choices = choices {
                // hack for finding out if it's a photo question:
                for choice in choices {
                    if choice.photoId?.characters.count > 0 {
                        isTextQuestion = false
                        break
                    }
                }
                
                if isTextQuestion {
                    iconImageView.image = nil
                    iconImageView.layer.borderWidth = 0.0
                    
                    if self.textThumbnailCache.object(forKey: question.id as AnyObject) == nil, choices.count > 0 {
                        var infoString = NSLocalizedString("text_question", comment: "") + "<br/>"
                        let title = NSLocalizedString("text_question", comment: "")
                        
                        if choices.count > 0 {
                            for i in 0...min(choices.count, 3) - 1 {
                                if let choiceText = choices[safe: i]?.text {
                                    var tempText = choiceText.trim().length > 0 ? "- \(choiceText)" : "- \(NSLocalizedString("choice_choice", comment: "")) \(i+1)"
                                    if(tempText.length > 12 && choices[safe: i]?.url == nil){
                                        tempText = String(tempText.characters.prefix(12)) + "..."
                                    }
                                    infoString += tempText + "<br/>"
                                }
                            }
                        }
                        infoString += choices.count > 3 ? "- ..." : ""
                        
                        let alignLeft = NSMutableParagraphStyle()
                        alignLeft.alignment = NSTextAlignment.left
                        alignLeft.lineSpacing = 1
                        
                        let labelText = try! NSMutableAttributedString(data: infoString.data(using: String.Encoding.unicode, allowLossyConversion: true)!,
                                                                       options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType],
                                                                       documentAttributes: nil)
                        labelText.addAttribute(NSFontAttributeName, value: UIFont.systemFont(ofSize: 7), range: NSMakeRange(0, labelText.length))
                        labelText.addAttribute(NSFontAttributeName, value: UIFont.boldSystemFont(ofSize: 6), range: NSMakeRange(0, min(title.length, labelText.length)))
                        labelText.addAttribute(NSParagraphStyleAttributeName, value: alignLeft, range: NSMakeRange(0,labelText.length))
                        
                        // cache calculated values:
                        self.textThumbnailCache.setObject(labelText, forKey: question.id as AnyObject)
                        self.imageThumbnailCache.removeObject(forKey: question.id as AnyObject)
                    } else if question.isChatOnly {
                        // If chat, but no image selected
                        let defaultIcon = UIImage(named: "LoginIcon")!
                        iconImageView.layer.borderWidth = 2.0
                        iconImageView.layer.masksToBounds = false
                        iconImageView.layer.borderColor = UIColor.white.cgColor
                        iconImageView.layer.cornerRadius = (iconImageView.frame.size.width)/2
                        iconImageView.clipsToBounds = true
                        iconImageView.image = self.imageThumbnailCache.object(forKey: question.id as AnyObject) as? UIImage
                        
                        User.fetchUsers(questionId: question.id, completion: {users, error in
                            if let user = users?.filter({$0.user_id != GlobalQuestionData.user_id}).first, users?.count == 2 {
                                user.fetchPhoto({image, error in
                                    if let image = image {
                                        self.imageThumbnailCache.setObject(image, forKey: question.id as AnyObject)
                                        if question.id != cell.objectId {
                                            return
                                        }
                                        iconImageView.image = image
                                    } else {
                                        self.imageThumbnailCache.setObject(defaultIcon, forKey: question.id as AnyObject)
                                        if question.id != cell.objectId {
                                            return
                                        }
                                        iconImageView.image = defaultIcon
                                    }
                                })
                            } else {
                                self.imageThumbnailCache.setObject(defaultIcon, forKey: question.id as AnyObject)
                                if question.id != cell.objectId {
                                    return
                                }
                                iconImageView.image = defaultIcon
                            }
                        })
                    }
                    
                    textQuestionInfoLabel.attributedText = self.textThumbnailCache.object(forKey: question.id as AnyObject) as? NSAttributedString
                    
                    
                    
              
                } else {
                    // photo question:
                    textQuestionInfoLabel.text = ""
                    iconImageView.layer.borderWidth = 2.0
                    iconImageView.layer.masksToBounds = false
                    iconImageView.layer.borderColor = UIColor.white.cgColor
                    iconImageView.layer.cornerRadius = (iconImageView.frame.size.width)/2
                    iconImageView.clipsToBounds = true
                    
                    if self.imageThumbnailCache.object(forKey: question.id as AnyObject) == nil {
                        let pictureChoices = choices.filter({$0.photoId != nil})
                        
                        let thumbnail_dispatchGroup = DispatchGroup()
                        for pictureChoice in pictureChoices {
                            thumbnail_dispatchGroup.enter()
                            if pictureChoice.picture == nil {
                                pictureChoice.photo() { (photo, error) in
                                    //                                    if let photo = photo {
                                    //                                        pictureChoice.picture = photo
                                    //                                    }
                                    thumbnail_dispatchGroup.leave()
                                }
                            } else {
                                thumbnail_dispatchGroup.leave()
                            }
                        }
                        
                        thumbnail_dispatchGroup.notify(queue: DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.low), execute: {
                            let thumbnails = choices.flatMap({$0.picture}).prefix(4)
                            
                            if thumbnails.count == 1{
                                self.imageThumbnailCache.setObject(thumbnails[0], forKey: question.id as AnyObject)
                            } else if thumbnails.count == 2{
                                let size = CGSize(width: iconImageView.frame.size.width*2, height: iconImageView.frame.size.height*2)
                                let split = size.height / 2
                                
                                UIGraphicsBeginImageContext(size)
                                
                                let topSize = CGRect(x: 0, y: 0, width: size.width, height: split - 1)
                                thumbnails[0].draw(in: topSize)
                                
                                let bottomSize = CGRect(x: 0, y: split + 1, width: size.width, height: split - 1)
                                thumbnails[1].draw(in: bottomSize)
                                let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                                UIGraphicsEndImageContext()
                                
                                self.imageThumbnailCache.setObject(thumbnail!, forKey: question.id as AnyObject)
                            } else if thumbnails.count == 3{
                                let size = CGSize(width: iconImageView.frame.size.width*2, height: iconImageView.frame.size.height*2)
                                let splitX = size.width / 2
                                let splitY = size.height / 2
                                
                                UIGraphicsBeginImageContext(size)
                                
                                let topLeftSize = CGRect(x: 0, y: 0, width: splitX - 1, height: splitY - 1)
                                thumbnails[0].draw(in: topLeftSize)
                                let topRightSize = CGRect(x: splitX + 1, y: 0, width: splitX - 1, height: splitY - 1)
                                thumbnails[1].draw(in: topRightSize)
                                let bottomSize = CGRect(x: 0, y: splitY + 1, width: size.width, height: splitY - 1)
                                thumbnails[2].draw(in: bottomSize)
                                
                                let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                                UIGraphicsEndImageContext()
                                
                                self.imageThumbnailCache.setObject(thumbnail!, forKey: question.id as AnyObject)
                            } else if thumbnails.count == 4{
                                let size = CGSize(width: iconImageView.frame.size.width*2, height: iconImageView.frame.size.height*2)
                                let splitX = size.width / 2
                                let splitY = size.height / 2
                                
                                UIGraphicsBeginImageContext(size)
                                
                                let topLeftSize = CGRect(x: 0, y: 0, width: splitX - 1, height: splitY - 1)
                                thumbnails[0].draw(in: topLeftSize)
                                let topRightSize = CGRect(x: splitX + 1, y: 0, width: splitX - 1, height: splitY - 1)
                                thumbnails[1].draw(in: topRightSize)
                                let bottomLeftSize = CGRect(x: 0, y: splitY + 1, width: splitX - 1, height: splitY - 1)
                                thumbnails[2].draw(in: bottomLeftSize)
                                let bottomRightSize = CGRect(x: splitX + 1, y: splitY + 1, width: splitX - 1, height: splitY - 1)
                                thumbnails[3].draw(in: bottomRightSize)
                                
                                let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                                UIGraphicsEndImageContext()
                                
                                self.imageThumbnailCache.setObject(thumbnail!, forKey: question.id as AnyObject)
                            }
                            
                            for choice in choices {
                                choice.picture = nil
                            }
                            
                            if self.imageThumbnailCache.object(forKey: question.id as AnyObject) != nil {
                                DispatchQueue.main.async(execute: {
                                    if question.id != cell.objectId {
                                        return
                                    }
                                    iconImageView.image = self.imageThumbnailCache.object(forKey: question.id as AnyObject) as? UIImage
                                })
                            }
                        })
                    } else {
                        iconImageView.image = self.imageThumbnailCache.object(forKey: question.id as AnyObject) as? UIImage
                        iconImageView.setNeedsLayout()
                        iconImageView.setNeedsDisplay()
                        iconImageView.layoutIfNeeded()
                    }
                }
            }
        }
        iconImageView.layer.borderWidth = 2.0
        iconImageView.layer.masksToBounds = false
        iconImageView.layer.borderColor = UIColor.white.cgColor
        iconImageView.layer.cornerRadius = (iconImageView.frame.size.width)/2
        iconImageView.clipsToBounds = true
        // title/text:
        let q_title:UILabel? = cell.viewWithTag(101) as? UILabel
        q_title?.text = question.text
        
        if question.isChatOnly {
            User.fetchUsers(questionId: question.id) { (users, error) in
                if question.id != cell.objectId {
                    return
                }
                if let users = users, users.count == 2 {
                    let otherUser = users.filter({$0.user_id != GlobalQuestionData.user_id}).first
                    q_title?.text = otherUser?.username
                }
            }
            
//            let chatTap = UITapGestureRecognizer(target:self, action:#selector(chatIconTapped))
//            iconImageView.isUserInteractionEnabled = true
//            iconImageView.addGestureRecognizer(chatTap)
        } else {
            iconImageView.gestureRecognizers?.forEach(iconImageView.removeGestureRecognizer(_:))
        }
        
        // creator name:
        let creatorNotice:UILabel? = cell.viewWithTag(102) as? UILabel
        if !question.isPublic && !question.isChatOnly {
            User.fetchUsers(userId: question.creatorId) { (users, error) in
                if let creator = users?.first {
                    creatorNotice?.text = NSString(format: NSLocalizedString("question_subtitle", comment: "Question creator") as NSString, creator.username) as String
                }
            }
        } else {
            creatorNotice?.text = ""
        }
        
        let lastActivityLabel = cell.viewWithTag(103) as! UILabel
        if !question.isPublic {
            question.mostRecentActivityDescription { (activityDescription) in
                if question.id != cell.objectId {
                    return
                }
                lastActivityLabel.text = activityDescription
            }
        } else {
            lastActivityLabel.text = ""
        }
        
        let date = cell.viewWithTag(108) as! UILabel
        if question.isPublic {
            date.text = ""
        } else {
            let formatter = Date.WMCDateformatter.copy() as! DateFormatter
            if(NSCalendar.current.isDateInToday(question.lastModification)){
                formatter.dateStyle = .none
            } else {
                formatter.timeStyle = .none
            }
            
       //     print(" question.lastModification) = \(question.lastModification)")
        //    print("formatter.string(from: question.lastModification) = \(formatter.string(from: question.lastModification))")
            date.text = formatter.string(from: question.lastModification)
        }
        
        let muteIconImageView = cell.viewWithTag(104) as! UIImageView
        muteIconImageView.isHidden = !question.isMuted || question.isPublic
        for constraint in muteIconImageView.constraints {
            if constraint.identifier == "muteWidth" {
                constraint.constant = question.isMuted && !question.isPublic ? 24 : 0
            }
        }
        
        let broadcastIcon:UIImageView = cell.viewWithTag(105) as! UIImageView
        broadcastIcon.isHidden = !question.isLinkSharingAllowed()
        for constraint in broadcastIcon.constraints {
            if constraint.identifier == "broadcastWidth" {
                constraint.constant = question.isLinkSharingAllowed() ? 24 : 0
            }
        }
        
        let highlightIcon:UIImageView = cell.viewWithTag(115) as! UIImageView
        let highlighted = Set(UserDefaults.standard.object(forKey: "highlighted") as? [Int] ?? [Int]())
        highlightIcon.isHidden = !highlighted.contains(question.id.rawId()!)
        for constraint in highlightIcon.constraints {
            if constraint.identifier == "highlightWidth" {
                constraint.constant = highlighted.contains(question.id.rawId()!) ? 24 : 0
            }
        }
        
        let unseenIconImageView = cell.viewWithTag(106) as? UIImageView
        let unseenLabel = cell.viewWithTag(107) as? UILabel
        // unseen handling:
        if let unseenIconImageView = unseenIconImageView, let unseenLabel = unseenLabel {
            var unseenCountString: String? = nil
            var unseenIconImage: UIImage? = nil
            
            if question.isUnseen {
                unseenCountString = NSLocalizedString("question_new", comment:"NEW text")
            } else if question.unseenCountChoices > 0 {
                unseenCountString = "\u{2753}\(question.unseenCountChoices)"
                unseenIconImage = UIImage(imageLiteralResourceName: "ic_new_vote_color")
            } else if question.unseenCountComments > 0 {
                unseenCountString = "\(question.unseenCountComments)"
                unseenIconImage = UIImage(imageLiteralResourceName: "ic_new_comment")
            } else if question.unseenCountRatings > 0 {
                unseenCountString = "\(question.unseenCountRatings)"
                unseenIconImage = UIImage(imageLiteralResourceName: "ic_new_vote_color")
            }
            
            unseenLabel.text = unseenCountString
            unseenIconImageView.image = unseenIconImage
            
            unseenLabel.isHidden = question.unseenCountTotal() == 0 && !question.isUnseen
            unseenIconImageView.isHidden = question.unseenCountTotal() == 0
            
            if(question.isMuted){
                unseenLabel.textColor = UIColor(redInt: 0xD7, greenInt: 0xD7, blueInt: 0xD7, alphaInt: 0xFF)
            } else{
                unseenLabel.textColor = UIColor(redInt: 0xFF, greenInt: 0x00, blueInt: 0x00, alphaInt: 0xFF)
            }
        }
        
        if(question.isPublic){
            broadcastIcon.isHidden = true
            let voteButton:UIButton = cell.viewWithTag(112) as! UIButton
            voteButton.isHidden = !question.isPublic
            if question.unseenCountRatings > 0 {
                voteButton .setTitle(String(question.unseenCountRatings), for: UIControlState.normal)
            }
            voteButton.addTarget(self, action: #selector(voteIconPress), for:.touchUpInside)
            
            let chatButton:UIButton = cell.viewWithTag(113) as! UIButton
            chatButton.isHidden = !question.isPublic
            if question.unseenCountComments > 0 {
                chatButton .setTitle(String(question.unseenCountComments), for: UIControlState.normal)
            }
            chatButton.addTarget(self, action: #selector(chatIconPress), for:.touchUpInside)

        }
        
        return cell
    }
    func chatIconPress(sender:UIButton!) {
        if let cell = sender.superview?.superview as? UITableViewCell {
            let indexPath = self.parent.tableView.indexPath(for: cell)
            self.parent.chatIconPress(indexPath: indexPath!)                    
        }
    }
    func voteIconPress(sender:UIButton!) {
        if let cell = sender.superview?.superview as? UITableViewCell {
            let indexPath = self.parent.tableView.indexPath(for: cell)
            self.parent.voteIconPress(indexPath: indexPath!)
        }
    }
    func chatIconTapped(sender: UITapGestureRecognizer){
        let iconImageView = sender.view
        if let cell = iconImageView?.superview?.superview as? UITableViewCell,
            let question = questionList[safe: self.parent.tableView.indexPath(for: cell)?.row ?? -1],
            question.isChatOnly {
            let infoController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "UserInfoController") as! UserInfoController
            infoController.set(question: question)
            
            let height = NSLayoutConstraint(item: infoController.view, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: self.parent.view.frame.height * 0.50)
            infoController.view.addConstraint(height);
            
            let userAlert = UIAlertController(title: "", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            userAlert.setValue(infoController, forKey: "contentViewController")
            userAlert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .default, handler: nil))
            
            self.parent.present(userAlert, animated: true, completion: nil)
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if(editingStyle == .delete){
            if let question = questionList[safe: indexPath.row]{
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
                
                if(!question.isPublic){
                    let isMuted = question.isMuted
                    alert.addAction(UIAlertAction(title: NSLocalizedString(isMuted ? "string_unmute_question" : "string_mute_question", comment: ""), style: .default) { alertAction in
                        Question.setMuted(questionId: question.id, muted: !isMuted) { (hasBeenChanged, error) in
                            Adjust.trackEvent(ADJEvent(eventToken: "yl42jj"))
                            self.parent.reloadQuestions()
                        }
                    })
                }
                
                let prefs = UserDefaults.standard
                if !question.isChatOnly {
                    var highlighted = Set(prefs.object(forKey: "highlighted") as? [Int] ?? [Int]())
                    let isHighlighted = highlighted.contains(question.id.rawId()!)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("highlight_question", comment: ""), style: .default){ alertAction in
                        if(isHighlighted){
                            highlighted.remove(question.id.rawId()!)
                            Adjust.trackEvent(ADJEvent(eventToken: "ab2gdw"))
                        } else{
                            highlighted.insert(question.id.rawId()!)
                            Adjust.trackEvent(ADJEvent(eventToken: "fz73r7"))
                        }
                        prefs.set(Array(highlighted), forKey: "highlighted")
                        
                        tableView.reloadData()
                    })
                }
                
                if(!question.isOwn()){
                    alert.addAction(UIAlertAction(title: NSLocalizedString("string_block_contact", comment: ""), style: .default){ alertAction in
                        let contactId = question.creatorId.components(separatedBy: "/")[1]
                        
                        User.addToContacts(userIds: [contactId], relationType: .BLACKLIST) { (error) in
                            if error == nil {
                                Adjust.trackEvent(ADJEvent(eventToken: "gc1g11"))
                                self.parent.reloadQuestions(userBlocked: question.creatorId)
                            }
                        }
                    })
                }
                
                var deleteDescription = NSLocalizedString("string_delete_question", comment: "")
                if question.isPublic {
                    deleteDescription = NSLocalizedString("hide_question", comment: "")
                } else if question.isChatOnly {
                    deleteDescription = NSLocalizedString("string_delete_chat", comment: "")
                }
                
                alert.addAction(UIAlertAction(title: deleteDescription, style: .destructive){alertAction in
                    if(question.isPublic){
                        let prefs = UserDefaults.standard
                        var publicBlacklist = prefs.stringArray(forKey: "public_blacklist") ?? [String]()
                        publicBlacklist.append(question.id)
                        prefs.set(publicBlacklist, forKey: "public_blacklist")
                    }
                    
                    objc_sync_enter(self)
                    User.fetchUsers(questionId: question.id, callbackOnce: true, completion: { users, error in
                            if let users = users{
                                let me = users.filter({$0.user_id == GlobalQuestionData.user_id})
                                
                                if(me.count > 0){
                                    if(!question.isPublic){
                                        _ = Comment.sendComment(question.id, text: nil, photo: nil, leave: 1, completion: {_,_ in })
                                    }
                                    
                                    if(!question.isRandomVoting){
                                        Question.removeParticipant(questionId: question.id, participantId: "users/\(GlobalQuestionData.user_id)") { (hasBeenDeleted, error) in
                                            if error == nil {
                                                Adjust.trackEvent(ADJEvent(eventToken: "v6eqf4"))
                                                self.parent.reloadQuestions()
                                            }
                                        }
                                    } else {
                                        self.parent.reloadQuestions()
                                    }
                                }
                            }
                            objc_sync_exit(self)
                        })
                    
                })
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("cancel",comment:""), style: .cancel, handler: nil))
                
                if let cell = tableView.cellForRow(at: indexPath){
                    alert.popoverPresentationController?.sourceView = cell
                    alert.popoverPresentationController?.sourceRect = CGRect(x: 200, y: 0, width: cell.frame.width - 200, height: cell.frame.height)
                } else {
                    alert.popoverPresentationController?.sourceView = self.parent.view
                }
                
                parent.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func synced(lock: AnyObject, closure: () -> ()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
    //    class SaveContactsDelegate : ContactsTask.ContactsTaskDelegate {
    //        override func onPostExecute(result: ([User]?, [UserGroup]?)) {
    //            print("Blocked contact")
    //        }
    //    }
    
    func unseenCountTotal() -> Int {
        var total = 0
        for question in questionList {
            total += question.unseenCountTotal()
        }
        return total
    }
    
}
