//
//  JITabBarController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 10/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import UIKit
import Adjust
import OAStackView
import SafariServices
import BBBadgeBarButtonItem

class PrivateVotingListController : VotingListViewController {
    
    var questionController:QuestionListController? = nil
    var privateQuestionList = [Question]()
    let instance = self
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.localizeStrings()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        UserDefaults().set(self.title, forKey: "selectedClass")
//        UserDefaults().synchronize()
        tableView.delegate = self
        
        self.questionController = QuestionListController(parent: self, questionList: [Question]())
        self.tableView.dataSource = self.questionController
        
        NotificationCenter.default.addObserver(self, selector: #selector(newDataDidBecomeAvailable), name: NSNotification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
        
        if self.refreshControl == nil {
            self.refreshControl = UIRefreshControl()
            self.refreshControl!.backgroundColor = UIColor(white: 0.8, alpha: 1.0)
            self.refreshControl!.tintColor = UIColor.white
            self.refreshControl?.addTarget(self, action: #selector(PrivateVotingListController.refresh(_:)), for: UIControlEvents.valueChanged)
        }
        
        let prefs = UserDefaults.standard
        let showHelp = prefs.object(forKey: "app_first_time") as? Int ?? 0
        if showHelp < 3 {
            self.navigationItem.rightBarButtonItem?.style = UIBarButtonItemStyle.plain
            
            prefs.set(showHelp+1, forKey: "app_first_time")
        } else {
            self.navigationItem.rightBarButtonItem?.style = UIBarButtonItemStyle.done
        }
        
//        let badgeItem = (self.navigationItem.leftBarButtonItem as! BBBadgeBarButtonItem)
//        let badgeButton = UIButton(type: .system)
//        badgeButton.addTarget(self, action: #selector(chatToggleTapped(_:)), for: .touchUpInside)
//        badgeButton.setImage(UIImage(named: "ic_chat_ios")!, for: .normal)
//        badgeButton.tintColor = UIColor.white
//        badgeButton.sizeToFit()
//        badgeItem.customView = badgeButton
        
//        let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(chatToggleTapped(_:)))
//        badgeItem.customView!.isUserInteractionEnabled = true
//        badgeItem.customView!.addGestureRecognizer(tapGestureRecognizer)
        
//        badgeItem.tintColor = UIColor.white
//        badgeItem.badgeTextColor = UIColor.judgeItPrimaryColor
//        badgeItem.badgeBGColor = UIColor.white
//        badgeItem.shouldHideBadgeAtZero = true
//        badgeItem.shouldAnimateBadge = true
//        badgeItem.badgeOriginX = -8
//        badgeItem.badgeOriginY = -8
        
        
        reloadQuestions()
    }
    
    override func viewDidAppear(_ animated: Bool){
        super.viewDidAppear(animated)
        
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "VotingList")
        tracker?.send((GAIDictionaryBuilder.createScreenView().build() as NSDictionary) as! [AnyHashable: Any])
    }
    
    
    func refresh(_ sender:AnyObject) {
        self.reloadQuestions()
    }
    
    func newDataDidBecomeAvailable(_ notification: Notification) {
        reloadQuestions()
    }
    
    // Returns currently visible part that would not require a new notification
    func getVisibleUpdate() -> (question_id: Int, type: UpdateType?){
        return (-1,nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.tabBarController?.tabBar.isHidden = false
        
        if (self.refreshControl == nil){
            self.refreshControl = UIRefreshControl()
            self.refreshControl!.backgroundColor = UIColor(white: 0.8, alpha: 1.0)
            self.refreshControl!.tintColor = UIColor.white
            self.refreshControl?.addTarget(self, action: #selector(refresh), for: UIControlEvents.valueChanged)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        reloadQuestions()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.idOfQuestionToSelect = nil
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    func applicationDidBecomeActive() {
        self.reloadQuestions()
    }
    
    var selectedQuestion:Question? = nil
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if let selectedQuestion = questionController?.questionList[safe: indexPath.row] {
            // Automatically go to tab of activity if only that happened
            if selectedQuestion.unseenCountComments > 0 && selectedQuestion.unseenCountTotal() == selectedQuestion.unseenCountComments{
                self.tabOfQuestionToSelect = VotingViewController.TabTag.chat
            }
            if selectedQuestion.unseenCountRatings > 0 && selectedQuestion.unseenCountTotal() == selectedQuestion.unseenCountRatings {
                self.tabOfQuestionToSelect = VotingViewController.TabTag.results
            }
            
            self.tabBarController?.tabBar.isHidden = true
            if let tabBarController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "VotingViewController") as? VotingViewController {
                tabBarController.question = selectedQuestion
                if let tabOfQuestionToSelect = self.tabOfQuestionToSelect {
                    tabBarController.initTabPosition = tabBarController.indexOfItemWithTag(tabOfQuestionToSelect.rawValue) ?? 0
                    tabBarController.selectedIndex = tabBarController.initTabPosition
                    self.tabOfQuestionToSelect = nil
                }
                self.navigationController?.pushViewController(tabBarController, animated: true)
            }
        }
    }
    
//    @IBAction func toggleEditing(sender: AnyObject){
//        self.setEditing(!self.editing, animated: true)
//    }
//    
//    override func setEditing(editing: Bool, animated: Bool) {
//        super.setEditing(editing, animated: animated)
//        navigationItem.leftBarButtonItem = editButtonItem()
//    }
    
    var showChat = false
    
    func chatToggleTapped(_ sender: AnyObject) {
        
        toggleChatVotings(chat: !showChat)
        
//        let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
//        
//        let markAction = UIAlertAction(title: NSLocalizedString("mark_all_read", comment: ""), style: .default){ alertAction in
//            Question.makeAllSeen({ (ids, error) in
//                self.reloadQuestions()
//            })
//        }
//        markAction.isEnabled = self.questionController!.unseenCountTotal() > 0
//        alert.addAction(markAction)
//        
//        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel",comment:""), style: .cancel, handler: nil))
//        
//        alert.popoverPresentationController?.barButtonItem = sender as! UIBarButtonItem
//        
//        present(alert, animated: true, completion: nil)
    }
    
    var chatBadgeCount = 0
    var questionBadgeCount = 0
    
    func toggleChatVotings(chat: Bool){
        showChat = chat
        questionController?.questionList = self.privateQuestionList.filter({$0.isChatOnly == self.showChat})
//        updateBadge()
        self.tableView.reloadData()
    }
    
    func updateBadge(){
        sumBadgeCount()
        let badgeItem = (self.navigationItem.leftBarButtonItem as! BBBadgeBarButtonItem)
        (badgeItem.customView as! UIButton).setImage(UIImage(named: (showChat ? "ic_vote_ios" : "ic_chat_ios"))!, for: .normal)
        badgeItem.badgeValue = showChat ? "\(questionBadgeCount)" : "\(chatBadgeCount)"
    }
    
    func sumBadgeCount() {
        chatBadgeCount = 0
        questionBadgeCount = 0
        for question in self.privateQuestionList {
            if question.isChatOnly {
                if question.isUnseen {
                    chatBadgeCount += 1
                } else {
                    chatBadgeCount += question.unseenCountTotal()
                }
            } else {
                if question.isUnseen {
                    questionBadgeCount += 1
                } else {
                    questionBadgeCount += question.unseenCountTotal()
                }
            }
        }
        
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 85.0
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 26
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return makeTableViewHeaderView(title: NSLocalizedString(showChat ? "chat_votings" : "private_votings", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "")
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let editAction = UITableViewRowAction(style: .default, title: NSLocalizedString("voting_options", comment:""), handler: {rowAction, editIndexPath in
            self.questionController?.tableView(tableView, commit: .delete, forRowAt: editIndexPath)
        })
        editAction.backgroundColor = UIColor.gray
        
        return [editAction]
    }
    
    // Notification support:
    var idOfQuestionToSelect: String?
    var tabOfQuestionToSelect: VotingViewController.TabTag?
    
    override func selectQuestion(_ questionId: String, tab: VotingViewController.TabTag) {
        let matchingQuestions = self.privateQuestionList.filter({ (question) -> Bool in
            return question.id == questionId
        })
        
        if let question = matchingQuestions.first {
//            toggleChatVotings(chat: question.isChatOnly)
            
            self.idOfQuestionToSelect = nil
            self.tabOfQuestionToSelect = tab
            
            if let row = self.questionController?.questionList.index(of: question) {
                let delayTime = DispatchTime.now() + Double(Int64(0.3 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                
                DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {
                    let indexPath = IndexPath(row: row, section: 0)
                    
                    // try to get rid of the top level tab bar:
                    self.tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
                    self.tableView(self.tableView, didSelectRowAt: indexPath)
                    //self.table
                })
            }
        } else {
            if idOfQuestionToSelect == nil {
                self.idOfQuestionToSelect = questionId
                self.tabOfQuestionToSelect = tab
                self.reloadQuestions(forced: true)
            } else {
                print("Reloading didn't reveal missing question. Maybe deleted meanwhile?")
            }
        }
    }
    
    override func reloadQuestions(forced: Bool = false, userBlocked: String? = nil) -> Void {
        Question.fetchQuestions(questionId: nil, alsoCached: !forced) { (questions, error) in
            self.refreshControl?.endRefreshing()
            
            //            User.fetchContacts("users/\(GlobalQuestionData.user_id)", completion: {contacts, error in
            //                if error == nil, let blockeds = contacts?.filter({$0.relation == .BLACKLIST}){
            //
            //                    if let questions = questions?.filter({question in !blockeds.contains({user in user.id() == question.creatorId})}) {
            //
            if var questions = questions {
                self.privateQuestionList = questions
                questions = self.privateQuestionList.filter({$0.isChatOnly == self.showChat})
                
                if let questionController = self.questionController {
                    if questionController.updateQuestions(questions) {
                        self.tableView.reloadData()
                    }
                } else {
                    self.questionController = QuestionListController(parent: self, questionList: questions)
                    self.tableView.dataSource = self.questionController
                    self.tableView.reloadData()
                }
                
//                self.updateBadge()
                AppDelegate.rootTabBarController?.updateTabBadges()
                
                if let idOfQuestionToSelect = self.idOfQuestionToSelect, let tabOfQuestionToSelect = self.tabOfQuestionToSelect {
                    self.selectQuestion(idOfQuestionToSelect, tab: tabOfQuestionToSelect)
                }
            }
            
            //                }
            //            })
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        self.reloadQuestions()
    }
    
}
