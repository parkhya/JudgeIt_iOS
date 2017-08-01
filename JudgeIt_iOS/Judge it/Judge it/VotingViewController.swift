//
//  VotingViewController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 17/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import UIKit
import AudioToolbox

class VotingViewController : UITabBarController, UITabBarControllerDelegate {
    
    enum TabTag: Int {
        case voting = 0
        case results = 1
        case chat = 2
    }
    
    var question:Question?
    var initTabPosition:Int = 0
    
    override var selectedIndex: Int {
        didSet {
            self.tabBar(self.tabBar, didSelect: (self.selectedViewController?.tabBarItem)!) // why not called automatically?
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    lazy var editQuestionButton:UIBarButtonItem = UIBarButtonItem(image: UIImage(named: "ic_edit"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(VotingViewController.editButtonClicked))
    lazy var shareButton:UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.action, target: self, action: #selector(VotingViewController.shareQuestion(_:)))
    
    lazy var chatFollowupButton:UIBarButtonItem = UIBarButtonItem(image: UIImage(named: "ic_action_newquestion"), style: .plain, target: self, action: #selector(VotingViewController.createFollowup(_:)))
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(newDataDidBecomeAvailable), name: NSNotification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
        
        self.tabBar.tintColor = UIColor.judgeItPrimaryColor
        self.tabBar.barTintColor = UIColor.white
        
        navigationItem.rightBarButtonItem = editQuestionButton
        
        self.localizeStrings()
        
        //        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(VotingViewController.swipeRight))
        //        swipeRight.direction = UISwipeGestureRecognizerDirection.Right
        //        self.view.addGestureRecognizer(swipeRight)
        //        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(VotingViewController.swipeLeft))
        //        swipeLeft.direction = UISwipeGestureRecognizerDirection.Left
        //        self.view.addGestureRecognizer(swipeLeft)
    }
    
    //    func swipeLeft(){
    //        self.selectedIndex = min(2, self.selectedIndex + 1)
    ////        checkUpdateNotification(self.selectedIndex)
    //
    //        let subtitleView = navBarView?.viewWithTag(102) as! UILabel
    //        subtitleView.text = NSLocalizedString("title_section\(self.selectedIndex+1)", comment: "")
    //    }
    //
    //    func swipeRight(){
    //        if(self.selectedIndex == 0){
    //            self.navigationController?.popViewControllerAnimated(true)
    //        } else{
    //            self.selectedIndex = max(0, self.selectedIndex - 1)
    //
    ////            checkUpdateNotification(self.selectedIndex)
    //
    //            let subtitleView = navBarView?.viewWithTag(102) as! UILabel
    //            subtitleView.text = NSLocalizedString("title_section\(self.selectedIndex+1)", comment: "")
    //        }
    //    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //self.navigationItem.title = self.selectedViewController?.tabBarItem.title
        
        if question?.isChatOnly ?? false {
            self.tabBar.isHidden = true
        }
        
        reload()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
        if let votingListViewController = self.navigationController!.viewControllers[safe: (self.navigationController?.viewControllers.count)! - 2] as? VotingListViewController {
            votingListViewController.tabBarController?.tabBar.isHidden = true
            if !(question?.isChatOnly ?? false) {
                self.tabBar.isHidden = false
            }
        }
        
        self.navigationItem.backBarButtonItem?.title = ""
        
        if question != nil {
            for view in self.viewControllers!{
                if let questionFragment = view as? QuestionFragment{
                    questionFragment.passQuestion(question!)
                }
            }
        }
        
        if !(question?.isChatOnly ?? false) {
            self.selectedIndex = initTabPosition
        } else {
            self.tabBar.isHidden = true
        }
        
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "Voting")
        tracker?.send(GAIDictionaryBuilder.createScreenView().build() as NSDictionary as! [AnyHashable: Any])
        
        super.viewDidAppear(animated)
    }
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        
        if (self.question?.isRandomVoting ?? false) && !(viewController is ChoiceFragmentController) && !(self.question?.isOwn() ?? true) {
            
            let alertController = UIAlertController(title: nil, message: NSLocalizedString("public_vote_first", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            
            
            return false
        }
        return true
        
    }
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if question!.isChatOnly {
            User.fetchUsers(questionId: question!.id) { (users, error) in
                if let otherUser = users?.filter({$0.user_id != GlobalQuestionData.user_id}).first, users?.count == 2 {
                    self.navigationItem.title = otherUser.username
                } else {
                    self.navigationItem.title = self.question!.text
                }
            }
        } else {
            self.navigationItem.title = item.title; // already localized
        }
    }
    
    func updateUnseenCountBadges() {
        if let question = self.question, let tabBarItems = self.tabBar.items {
            for tabBarItem in tabBarItems {
                switch tabBarItem.tag {
                case 0:
                    if self.tabBar.selectedItem != tabBarItem {
                        // only update when not selected to avoid flickering
                        if question.unseenCountChoices != 0 {
                            tabBarItem.badgeValue = "\(question.unseenCountChoices)"
                        } else {
                            tabBarItem.badgeValue = nil
                        }
                    }
                    break
                    
                case 1:
                    if self.tabBar.selectedItem != tabBarItem {
                        // only update when not selected to avoid flickering
                        if question.unseenCountRatings != 0 {
                            tabBarItem.badgeValue = "\(question.unseenCountRatings)"
                        } else {
                            tabBarItem.badgeValue = nil
                        }
                    }
                    break
                    
                case 2:
                    if self.tabBar.selectedItem != tabBarItem {
                        // only update when not selected to avoid flickering
                        if question.unseenCountComments != 0 {
                            tabBarItem.badgeValue = "\(question.unseenCountComments)"
                            break
                        }
                    }
                    tabBarItem.badgeValue = nil
                    break
                    
                default:
                    tabBarItem.badgeValue = nil
                    break
                }
            }
        }
    }
    
    func screenshotButtonClicked(){
        self.selectedIndex = 1
        
        let delay = 0.5 * Double(NSEC_PER_SEC)
        let time = DispatchTime.now() + Double(Int64(delay)) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: time, execute: {
            let scrollView = self.selectedViewController!.view.viewWithTag(123) as! UIScrollView
            let tablePosition = scrollView.viewWithTag(195)?.convert(CGPoint.zero, to: scrollView)
            
            let screenshot = scrollView.takeScreenshot(tablePosition?.y)
            
            let activityViewController : UIActivityViewController = UIActivityViewController(
                activityItems: [/*description, */screenshot], applicationActivities: nil)
            activityViewController.title = NSLocalizedString("share_screenshot", comment: "")
            
            // This line remove the arrow of the popover to show in iPad
            activityViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 150, y: 150, width: 0, height: 0)
            
            // Anything you want to exclude
            activityViewController.excludedActivityTypes = [
                UIActivityType.postToWeibo,
                UIActivityType.print,
                UIActivityType.assignToContact,
                UIActivityType.saveToCameraRoll,
                UIActivityType.addToReadingList,
                UIActivityType.postToFlickr,
                UIActivityType.postToVimeo,
                UIActivityType.postToTencentWeibo
            ]
            
            self.present(activityViewController, animated: true, completion: nil)
            
            let statsController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "StatsController") as! StatsFragmentController
            statsController.passQuestion(self.question!)
            self.viewControllers![1] = statsController
            self.selectedViewController = self.viewControllers![1]
        })
        
    }
    
    func editButtonClicked() {
        if let question = self.question {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("share_screenshot", comment: ""), style: .default){alertAction in
                self.screenshotButtonClicked()
            })
            
            if !question.isPublic && question.id != GlobalQuestionData.INTRO_VOTING_ID {
                alert.addAction(UIAlertAction(title: NSLocalizedString("ask_followup", comment: ""), style: .default){alertAction in
                    // Create a new Question as followup question:
                    let newEditController: QuestionEditController = self.newQuestionEditController(asFollowup: true)
                    self.navigationController?.pushViewController(newEditController, animated: true)
                })
            }
            
            // User can invite others to his own questions:
            if (question.isOwn() && !question.isPublic){
                alert.addAction(UIAlertAction(title: NSLocalizedString("action_invite_question", comment: ""), style: .default){alertAction in
                    let newInviteController: QuestionInviteController = self.newQuestionInviteController()
                    self.navigationController?.pushViewController(newInviteController, animated: true)
                })
            }
            if (!question.isLinkSharingAllowed() && !question.isPublic) || question.isOwn() {
                // Add a Choice:
                alert.addAction(UIAlertAction(title: NSLocalizedString("add_choice", comment: ""), style: .default){alertAction in
                    let newEditController: QuestionEditController = self.newQuestionEditController(asFollowup: false)
                    newEditController.setInvitationsEditingEnabled(false);
                    newEditController.passEditQuestion(self.question!)
                    self.navigationController?.pushViewController(newEditController, animated: true)
                })
            }
            
            if(question.isOwn() && !question.isClosed && !question.isPublic){
                alert.addAction(UIAlertAction(title: NSLocalizedString("close_voting", comment: ""), style: .default){ alertAction in
                    let close_alert = UIAlertController(title: nil, message: NSLocalizedString("close_voting_prompt", comment: ""), preferredStyle: .alert)
                    close_alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: { (action) in
                        Question.setStopped(questionId: self.question!.id, stopped: true, completion: {success,_ in
                            if success {
                                _ = Comment.sendComment(question.id, text: nil, photo: nil, stop: 1, completion: {comment, error in
                                    if error == nil {
                                        NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
                                    }
                                })
                            }
                        })
                    }))
                    close_alert.addAction(UIAlertAction(title: NSLocalizedString("cancel",comment:""), style: .cancel, handler: nil))
                    
                    self.present(close_alert, animated: true, completion: nil)
                })
            }
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("cancel",comment:""), style: .cancel, handler: nil))
            
            alert.popoverPresentationController?.barButtonItem = self.editQuestionButton
            
            present(alert, animated: true, completion: nil)
        }
    }
    
    func createFollowup(_ sender: UIBarButtonItem){
        let newEditController: QuestionEditController = self.newQuestionEditController(asFollowup: true)
        self.navigationController?.pushViewController(newEditController, animated: true)
    }
    
    func newQuestionInviteController() -> QuestionInviteController {
        let inviteController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "QuestionInviteController") as! QuestionInviteController
        inviteController.passEditQuestion(question!)
        
        self.navigationController?.setNavigationBarHidden(false, animated: true) // TODO: Never hide
        return inviteController;
    }
    
    func newQuestionEditController(asFollowup: Bool) -> QuestionEditController {
        let questionEditController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "QuestionEditController") as! QuestionEditController
        if asFollowup {
            questionEditController.followedQuestion = question
        }
        
        return questionEditController;
    }
    
    func shareQuestion(_ sender: UIBarButtonItem){
        
        let urlString = "https://get.judge-it.net/broadcast/?share=1&ref="
        print(IDObfuscator.obfuscate(question!.id.rawId()!))
        
        if let shareUrl = URL(string: urlString + IDObfuscator.obfuscate(question!.id.rawId()!)){
            
            let username = GlobalQuestionData.userMap[GlobalQuestionData.user_id]?.username ?? NSLocalizedString("someone", comment: "")
            let appname = NSLocalizedString("app_name", comment: "")
            let shareText = NSString(format: NSLocalizedString("share_text_broadcast", comment: "") as NSString, username, question!.text, appname, appname, shareUrl.absoluteString) as String
            
            let activityViewController : UIActivityViewController = UIActivityViewController(
                activityItems: [shareText], applicationActivities: nil)
            
            // This lines is for the popover you need to show in iPad
            activityViewController.popoverPresentationController?.barButtonItem = sender
            
            // This line remove the arrow of the popover to show in iPad
            activityViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 150, y: 150, width: 0, height: 0)
            
            // Anything you want to exclude
            activityViewController.excludedActivityTypes = [
                UIActivityType.postToWeibo,
                UIActivityType.print,
                UIActivityType.assignToContact,
                UIActivityType.saveToCameraRoll,
                UIActivityType.addToReadingList,
                UIActivityType.postToFlickr,
                UIActivityType.postToVimeo,
                UIActivityType.postToTencentWeibo
            ]
            
            self.present(activityViewController, animated: true, completion: nil)
            
            //TODO
            //            self.navigationController?.navigationBar.setTitleTextAttributes([UITextAttributeTextColor:UIColor.whiteColor()])
            //            self.navigationController?.navigationBar.setTintColor(UIColor.whiteColor())
        } else{
            print("Error sharing")
        }
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        initTabPosition = self.selectedIndex
        //        UpdateService.instance.removeUpdateHandler(self)
    }
    
    func newDataDidBecomeAvailable(_ notification: Notification) {
        let noCache = notification.userInfo?["noCache"] as? Bool ?? true
        reload(forceNonCache: noCache)
    }
    
    func reload(forceNonCache: Bool = false) {
        DispatchQueue.global(priority: .default).async(execute: {
            Question.fetchQuestions(questionId: self.question!.id, alsoCached: !forceNonCache) { (questions, error) in
                if let questions = questions, let question = questions.first {
                    self.question = question
                    Question.makeOld(questionId: question.id, completion: { (ids, error) in })
                    DispatchQueue.main.async {
                        self.updateUnseenCountBadges()
                    }
                    
                    DispatchQueue.main.async {
                        // update right bar buttons:
                        if question.isChatOnly {
                            self.navigationItem.setRightBarButton(self.chatFollowupButton, animated: false)
                            
                            self.selectedIndex = 2
                            self.tabBar.isHidden = true
                        } else if question.isLinkSharingAllowed() {
                            self.navigationItem.setRightBarButtonItems([self.editQuestionButton, self.shareButton], animated: false)
                        }
                        
                        if let viewControllers = self.viewControllers {
                            for viewController in viewControllers {
                                if let questionFragment = viewController as? QuestionFragment {
                                    questionFragment.passQuestion(question)
                                }
                            }
                        }
                    }
                }
            }
        })
    }
    
}
