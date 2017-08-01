//
//  PublicVotingListController.swift
//  Judge it!
//
//  Created by Daniel Theveßen on 29/01/2017.
//  Copyright © 2017 Judge it. All rights reserved.
//

import Foundation
import UIKit
import Adjust
import OAStackView
import SafariServices

class PublicVotingListViewController : VotingListViewController {
    
    
    @IBOutlet var imgUser: UIImageView!
    
    @IBOutlet var btnTitleNewQuestion: UIButton!
    
    var profileUser: User?
    
    var questionController:QuestionListController? = nil
    var publicQuestionList = [Question]()
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
        
        self.reload(forced: true)
        
        self.questionController = QuestionListController(parent: self, questionList: [Question]())
        self.tableView.dataSource = self.questionController
        
        NotificationCenter.default.addObserver(self, selector: #selector(newDataDidBecomeAvailable), name: NSNotification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
        
        if self.refreshControl == nil {
            self.refreshControl = UIRefreshControl()
            self.refreshControl!.backgroundColor = UIColor(white: 0.8, alpha: 1.0)
            self.refreshControl!.tintColor = UIColor.white
            self.refreshControl?.addTarget(self, action: #selector(PublicVotingListViewController.refresh(_:)), for: UIControlEvents.valueChanged)
        }
        
        let prefs = UserDefaults.standard
        let showHelp = prefs.object(forKey: "app_first_time") as? Int ?? 0
        if showHelp < 3 {
            self.navigationItem.rightBarButtonItem?.style = UIBarButtonItemStyle.plain
            
            prefs.set(showHelp+1, forKey: "app_first_time")
        } else {
            self.navigationItem.rightBarButtonItem?.style = UIBarButtonItemStyle.done
        }
        
        loadRandomQuestions()
        reloadQuestions()
    }
    
    override func viewDidAppear(_ animated: Bool){
        super.viewDidAppear(animated)
        
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "VotingList")
        tracker?.send((GAIDictionaryBuilder.createScreenView().build() as NSDictionary) as! [AnyHashable: Any])
    }
    
    
    func refresh(_ sender:AnyObject) {
        if self.showOwnVotingsOnly {
            self.reloadQuestions()
        } else {
            self.loadRandomQuestions()
        }
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
        
        self.reload(forced: true)
        
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
        
        if !self.isMovingToParentViewController {
            self.toggleShownVotings(ownOnly: false)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    func applicationDidBecomeActive() {
        self.reloadQuestions()
    }
    
    var selectedQuestion:Question? = nil
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if let selectedQuestion = questionController?.questionList[safe: indexPath.row] {
            self.tabBarController?.tabBar.isHidden = true
            if let tabBarController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "VotingViewController") as? VotingViewController {
                tabBarController.question = selectedQuestion
                self.navigationController?.pushViewController(tabBarController, animated: true)
            }
        }
    }
    
    @IBAction func showActions(_ sender: UIBarButtonItem) {
        toggleShownVotings(ownOnly: !self.showOwnVotingsOnly)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100.0
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 26
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return makeTableViewHeaderView(title: NSLocalizedString(showOwnVotingsOnly ? "your_votings" : "random_votings", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "")
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        //        if self.showOwnVotingsOnly {
        let editAction = UITableViewRowAction(style: .default, title: NSLocalizedString("voting_options", comment:""), handler: {rowAction, editIndexPath in
            self.questionController?.tableView(tableView, commit: .delete, forRowAt: editIndexPath)
        })
        editAction.backgroundColor = UIColor.gray
        
        return [editAction]
        //        }
        //        return nil
    }
    
    override func chatIconPress(indexPath:IndexPath) {
        if let selectedQuestion = questionController?.questionList[safe: (indexPath.row)] {
            self.tabBarController?.tabBar.isHidden = true
            if let tabBarController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "ChatViewController") as? CommentFragmentController {
                tabBarController.question = selectedQuestion
                self.navigationController?.pushViewController(tabBarController, animated: true)
            }
        }
    }
    override func voteIconPress(indexPath:IndexPath) {        
        if let selectedQuestion = questionController?.questionList[safe: (indexPath.row)] {
            self.tabBarController?.tabBar.isHidden = true
            if let tabBarController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "VotingViewController") as? VotingViewController {
                tabBarController.question = selectedQuestion
                self.navigationController?.pushViewController(tabBarController, animated: true)
            }
        }
        //        }
    }
    // Notification support:
    var idOfQuestionToSelect: String?
    var tabOfQuestionToSelect: VotingViewController.TabTag?
    
    override func selectQuestion(_ questionId: String, tab: VotingViewController.TabTag) {
        toggleShownVotings(ownOnly: true)
        
        let matchingQuestions = self.publicQuestionList.filter({ (question) -> Bool in
            return question.id == questionId
        })
        
        if let question = matchingQuestions.first {
            self.idOfQuestionToSelect = nil
            self.tabOfQuestionToSelect = tab
            
            if let row = self.questionController?.questionList.index(of: question) {
                let delayTime = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                
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
    
    var showOwnVotingsOnly = false
    
    func toggleShownVotings(ownOnly: Bool){
        showOwnVotingsOnly = ownOnly
        questionController?.questionList = publicQuestionList.filter({!ownOnly || !$0.isRandomVoting})
        self.tableView.reloadData()
        self.navigationItem.leftBarButtonItem?.image = UIImage(imageLiteralResourceName: (showOwnVotingsOnly ? "ic_public_voting" : "ic_public_voting_own"))
    }
    
    func loadRandomQuestions(){
        Question.fetchPublicQuestions(own: false, alsoCached: false) { (questions, error) in
            self.refreshControl?.endRefreshing()
            if var questions = questions {
                // "Kick out" deleted random votings
                let publicBlacklist = Set(UserDefaults.standard.stringArray(forKey: "public_blacklist") ?? [String]())
                questions = questions.filter({!publicBlacklist.contains($0.id)})
                
                self.publicQuestionList = self.publicQuestionList.filter({!$0.isRandomVoting})
                
                questions.forEach({$0.isRandomVoting = true})
                self.publicQuestionList.append(contentsOf: questions)
                self.publicQuestionList.sort(by: {$0.0.lastModification > $0.1.lastModification})
                
                if let questionController = self.questionController {
                    if !self.showOwnVotingsOnly{
                        questionController.questionList = self.publicQuestionList
                        self.tableView.reloadData()
                    }
                } else {
                    self.questionController = QuestionListController(parent: self, questionList: self.publicQuestionList)
                    self.tableView.dataSource = self.questionController
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    override func reloadQuestions(forced: Bool = false, userBlocked:String? = nil) -> Void {
        if let userBlocked = userBlocked {
            self.publicQuestionList = self.publicQuestionList.filter({$0.creatorId != userBlocked})
        }
        
        let publicBlacklist = Set(UserDefaults.standard.stringArray(forKey: "public_blacklist") ?? [String]())
        self.publicQuestionList = self.publicQuestionList.filter({!publicBlacklist.contains($0.id)})
        
        Question.fetchPublicQuestions(own: true, alsoCached: !forced) { (questions, error) in
            self.refreshControl?.endRefreshing()
            if let questions = questions {
                if let questionController = self.questionController {
                    self.publicQuestionList = self.publicQuestionList.filter({$0.isRandomVoting})
                    self.publicQuestionList.append(contentsOf: questions)
                    self.publicQuestionList.sort(by: {$0.0.lastModification > $0.1.lastModification})
                    
                    if self.showOwnVotingsOnly && questionController.updateQuestions(questions) {
                        self.tableView.reloadData()
                    } else if !self.showOwnVotingsOnly {
                        self.questionController?.questionList = self.publicQuestionList
                        self.tableView.reloadData()
                    }
                } else {
                    self.questionController = QuestionListController(parent: self, questionList: questions)
                    self.tableView.dataSource = self.questionController
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    func reload(forced: Bool = false) {
        User.fetchProfile(alsoCached: !forced) { (profileUser, error) in
            if let profileUser = profileUser {
                self.profileUser = profileUser
                
                if self.view != nil {
                    self.profileUser?.fetchPhoto { (photo, error) in
                        if let photo = photo {
                            if profileUser === self.profileUser {
                                self.imgUser.image = photo
                            }
                        }
                    }
                }
                let name = NSString(format: NSLocalizedString("whats_up_prompt", comment: "") as NSString, (self.profileUser?.username)!) as String
                
                self.btnTitleNewQuestion .setTitle(name, for: UIControlState.normal)
            }
        }
    }
    
}
