//
//  QuestionEditController.swift
//  Judge it!
//
//  Created by Dirk Theisen on 08.09.16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation
import Adjust
import SwiftyJSON
import KMPlaceholderTextView

class QuestionEditController : UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate {
    
    fileprivate var editQuestion:Question? // set for editing existing questions
    fileprivate var inviteController:QuestionInviteController? // set for editing existing questions
    
    @IBOutlet internal var titleField2: KMPlaceholderTextView!
    
    @IBOutlet var followupLabel: UILabel!
    var lbl_Title: UILabel!
    @IBOutlet var tableView:UITableView!
    
    var lastSelected:Int?
    fileprivate var invitationsEditingEnabled = true
    
    fileprivate (set) var editableChoices = [Choice]()
    var followedQuestion: Question?
    
    fileprivate var nextResponderRow: Int = -1
    
    func setTitleEditingEnabled(_ enabled: Bool) {
        
        if (enabled) {
            titleField2.isEditable = true
            titleField2.layer.borderWidth = 1.0
            //titleField2?.backgroundColor = UIColor(red: 0xEF, green: 0xEF, blue: 0xEF) // HOW?
            
        } else {
            titleField2.isEditable = false
            titleField2.layer.borderWidth = 0.0
            titleField2?.backgroundColor = UIColor(red: 0xEF, green: 0xEF, blue: 0xEF)
        }
    }
    
    func setInvitationsEditingEnabled(_ enabled: Bool) {
        if (enabled) {
            // ???
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "ic_done_ios"), style: .plain, target: self, action: #selector(saveQuestion))
        }
        
        invitationsEditingEnabled = enabled;
    }
    
    @IBAction func next(_ sender: AnyObject) {
        if (self.inviteController == nil) {
            let nextViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "QuestionInviteController") as! QuestionInviteController
            // Save inviteController reference, so going back-and-forth does keep the state.
            self.inviteController = nextViewController
            if self.editQuestion != nil {
                self.inviteController!.passEditQuestion(self.editQuestion!);
            }
        }
        self.navigationController?.pushViewController(self.inviteController!, animated: true)
    }
    
    
    // Save changes to existing questions:
    @IBAction func saveQuestion(_ sender: AnyObject) {
        
        if  self.handleInvalidInput() {
            return
        }
        
        let newChoices = self.editableChoices.filter { (choice) -> Bool in
            return choice.isNew() && choice.isValid()
        }
        if newChoices.count > 0 {
            Choice.addChoices(questionId: self.editQuestion!.id, choicesDictionaries: Choice.dictionariesFromChoices(newChoices)) { (choices, error) in
                if error == nil {
                    //Adjust event: choices added
                    Adjust.trackEvent(ADJEvent(eventToken: "m2will"))
                    
                    if !self.editQuestion!.isPublic,
                        let choice = choices?.first,
                        let choice_str = choice.id.components(separatedBy: "/")[safe: 1],
                        let choice_id = Int(choice_str){
                        _ = Comment.sendComment(self.editQuestion!.id, text: nil, photo: nil, choices: choice_id, completion: {_,_ in })
                    }
                    
                    if let votingVC = self.navigationController?.viewControllers.filter({$0 is VotingViewController}).first as? VotingViewController {
                        votingVC.initTabPosition = VotingViewController.TabTag.voting.rawValue
                    }
                    _ = self.navigationController?.popViewController(animated: true)
                } else {
                    print("Error committing changes to server: ", error!)
                }
                NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
            }
        } else {
            _ = self.navigationController?.popViewController(animated: true)
        }
    }
    
    
    //    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    //        if segue.identifier == "inviteSeque" {
    //            let inviteController = segue.destinationViewController as! QuestionInviteController
    //
    //        }
    //    }
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.localizeStrings()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleField2.layer.borderColor = UIColor.judgeItBorderColor.cgColor
        titleField2.layer.cornerRadius = 5
        titleField2.clipsToBounds = true
        titleField2.delegate = self
        titleField2.placeholder = NSLocalizedString("question_default_title", comment: "")
        self.setTitleEditingEnabled(true) // default
        
        //        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(QuestionEditController.keyboardWillShow(_:)), name:UIKeyboardWillShowNotification, object: nil);
        //        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(QuestionEditController.keyboardWillHide(_:)), name:UIKeyboardWillHideNotification, object: nil);
        //        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(QuestionEditController.keyboardWillChange(_:)), name:UIKeyboardWillChangeFrameNotification, object: nil);
        //        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(QuestionEditController.keyboardWillChange(_:)), name:UITextInputCurrentInputModeDidChangeNotification, object:nil)
    }
    
    var keyboardShown = false
    var kbHeight:CGFloat? = nil
    func keyboardWillShow(_ sender: Notification) {
        if(!keyboardShown){
            
            if let kbHeight = (sender.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height{
                print("keyboard height \(kbHeight)")
                self.kbHeight = kbHeight
                
                let tableViewDiff = (kbHeight - self.tabBarController!.tabBar.frame.height - 50)
                self.tableView.frame.size = CGSize(width: self.tableView.frame.width, height: self.tableView.frame.height - tableViewDiff)
            }
        }
        keyboardShown = true
    }
    
    func keyboardWillChange(_ sender: Notification){
        if(keyboardShown){
            if let changedKbHeight = (sender.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height, kbHeight != nil{
                print("keyboard height \(changedKbHeight)")
                self.tableView.frame.size = CGSize(width: self.tableView.frame.width, height: self.tableView.frame.height + (changedKbHeight - self.kbHeight!))
                
                self.kbHeight = changedKbHeight
            }
        }
    }
    
    func keyboardWillHide(_ sender: Notification) {
        keyboardHide()
    }
    
    func keyboardHide(){
        if(keyboardShown){
            
            if let kbHeight = self.kbHeight{
                let tableViewDiff = (kbHeight - self.tabBarController!.tabBar.frame.height - 50)
                self.tableView.frame.size = CGSize(width: self.tableView.frame.width, height: self.tableView.frame.height + tableViewDiff)
                
                self.kbHeight = nil
            }
        }
        keyboardShown = false
    }
    
    
    func scrollToLastChoiceAndMakeFirstResponder() {
        if tableView == nil  || self.editableChoices.count == 0 {
            return
        }
        
        nextResponderRow = self.editableChoices.count-1
        
        self.tableView.reloadData()
        
        let lastIndexPath = IndexPath(row: self.editableChoices.count-1, section: 0)
        self.tableView!.scrollToRow(at: lastIndexPath, at: .bottom, animated: false)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.15 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
            self.tableView!.scrollToRow(at: lastIndexPath, at: .bottom, animated: false)
        })
    }
    
    func choiceTextViewShouldBeginEditing(_ notification: Notification) {
        if let choice = notification.object as? Choice, let lastChoice = self.editableChoices.last{
            if lastChoice === choice {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.15 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
                    let lastIndexPath = IndexPath(row: self.tableView.numberOfRows(inSection: 0) - 1, section: 0)
                    self.tableView!.scrollToRow(at: lastIndexPath, at: .bottom, animated: false)
                    
                    self.tableView.setNeedsLayout()
                    self.tableView.layoutIfNeeded()
                })
            }
        }
    }
    
    func validateUI() {
        if self.view != nil {
            if let followedQuestion = self.followedQuestion {
                followupLabel.text = NSLocalizedString("followup_question", comment: "") + " " + followedQuestion.text
                followupLabel.isHidden = false
            } else {
                followupLabel.isHidden = true
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        print("self.title = \(self.title)")
//        UserDefaults().set(self.title, forKey: "selectedClass")
//        UserDefaults().synchronize()
        
        //        // Create a new Question, if none was set until now:
        //        if (self.editQuestion == nil) {
        //            self.passEditQuestion(nil);
        //        }
        
        self.validateUI();
        
        if let lastChoice = self.editableChoices.last {
            // Add a Choice-Edit row, for quickly adding new rows.
            if (!lastChoice.isNew()) {
                addChoice(interactive: false)
            }
        } else {
            addChoice(interactive: false)
        }
        
        if (!invitationsEditingEnabled) {
            scrollToLastChoiceAndMakeFirstResponder()
        } else {
            titleField2.becomeFirstResponder()
        }
        
        super.viewWillAppear(animated)
        
        // this is not good enough; i.e. when user account changes
        let prefs = UserDefaults.standard
        let loadPhoneContacts = prefs.object(forKey: "phone_first_time") as? Bool ?? true
        if loadPhoneContacts {
            User.addMatchingPhoneContacts({ (addedContactUserIds, error) in
                if error == nil {
                    prefs.set(false, forKey: "phone_first_time")
                }
            })
        }
        self.title = NSLocalizedString(self.title!, comment: "")
   //   self.tit   NSLocalizedString(self.title, @"");
        
        let textWidth = self.view.frame.size.width / 2
        
        lbl_Title = UILabel(frame: CGRect(x: textWidth / 2, y: 20, width: textWidth, height: 43))
        lbl_Title.text = NSLocalizedString("NewVoting", comment: "")
        lbl_Title.textColor = UIColor.white
        lbl_Title.font = UIFont(name: "Amatic-Bold", size: 27)
        lbl_Title.backgroundColor = UIColor.init(colorLiteralRed: 255.0/255.0, green: 69.0/255.0, blue: 77.0/255.0, alpha: 1.0)
        lbl_Title.isOpaque = true
        lbl_Title.textAlignment = .center
        kAppDelegate.window?.addSubview(lbl_Title)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        lbl_Title.removeFromSuperview()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.tabBarController?.tabBar.isHidden = true
        
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "ChoiceCreate")
        tracker?.send((GAIDictionaryBuilder.createScreenView().build() as NSDictionary) as! [AnyHashable: Any])
        
        self.tableView.flashScrollIndicators()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            // Very funky way of capturing the return key:
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if let cell = textView.superview?.superview as? CreateChoiceTableViewCell {
            let choice = cell.choice
            choice?.text = textView.text;
        }
    }
    
    
    // Table view stuff
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.editableChoices.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let editable = self.editableChoices[indexPath.row].isNew()
        if !editable || indexPath.row != (editableChoices.count - 1){
            return 84.0
        }
        return tableView.rowHeight
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (indexPath.row == nextResponderRow) {
            cell.viewWithTag(101)?.becomeFirstResponder() // shows keyboard
            nextResponderRow = -1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "createChoiceCell") as! CreateChoiceTableViewCell
        
        let editable = self.editableChoices[indexPath.row].isNew()
        
        cell.setChoice(self.editableChoices[indexPath.row], choiceNumber: indexPath.row, editable: editable, scrollHandler: scrollToCell, addDateHandler: appendDates, additionalImageHandler: appendImages)
        
        if (editable) {
            cell.setChoice(self.editableChoices[indexPath.row], choiceNumber: indexPath.row, editable: true, scrollHandler: scrollToCell, addDateHandler: appendDates, additionalImageHandler: appendImages)
            if cell.removeButton.allTargets.count == 0 {
                cell.removeButton.addTarget(self, action: #selector(removeChoiceAction), for: .touchUpInside)
            }
            
            if cell.addButton.allTargets.count == 0 {
                cell.addButton.addTarget(self, action: #selector(addChoiceAction), for: .touchUpInside)
            }
            
            // add button only on last row:
            cell.addButton.isHidden = indexPath.row != (tableView.numberOfRows(inSection: 0) - 1)
            
            // only show media buttons on last row
            for mediaButton in cell.allMediaButtons {
                mediaButton.isEnabled = editable && indexPath.row == (tableView.numberOfRows(inSection: 0) - 1)
            }
            
            // don't let the user remove last choice cell:
            cell.removeButton.isHidden = self.editableChoices.count == 1
            
            cell.textView.delegate = self
        }
        cell.tableViewController = self;
        
        return cell
    }
    
    func scrollToCell(_ cell: UITableViewCell){
        if let index = tableView.indexPath(for: cell) {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.15 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
                self.tableView!.scrollToRow(at: index, at: .bottom, animated: false)
            })
        }
    }
    
    func passEditQuestion(_ question:Question) {
        self.editQuestion = question
        
        Choice.fetchChoices(question: question, choiceId: nil) { (choices, error) in
            self.editableChoices = choices ?? []
            self.addChoice(interactive: true)
            
            self.validateUI()
            
            // Start editing with existing question title:
            let questionTitle = self.editQuestion!.text
            self.titleField2!.text = questionTitle
            if (questionTitle.trim().length > 0) {
                self.setTitleEditingEnabled(false)
            }
            
            self.title = NSLocalizedString("add_choice", comment: "")
        }
    }
    
    func handleInvalidInput() -> Bool {
        
        
        self.view.window?.findFirstResponder()?.resignFirstResponder()
        
        let title = self.titleField2.text;
        
        if title != nil && title!.length < 3 {
            let alertController = UIAlertController(title: NSLocalizedString("invalid_title_title", comment: "Invalid question title title"), message: NSLocalizedString("invalid_title", comment: "Question title incomplete"), preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default, handler: nil))
            
            _ = self.navigationController?.popToViewController(self, animated: true); // in case we are not the topViewController
            self.present(alertController, animated: true, completion: {
                self.titleField2.becomeFirstResponder();
            })
            
            return true; // invalid input handled
        } else {
            
            var checkChoices = [Choice](self.editableChoices);
            if (checkChoices.count > 0) {
                if !(checkChoices.last?.isValid())! {
                    checkChoices.remove(at: checkChoices.count-1)
                }
            } else {
                // Complain here!
            }
            
            if !Question.choicesValid(checkChoices) {
                let alertController = UIAlertController(title: NSLocalizedString("invalid_choices_title", comment: "Choices incomplete - title"), message: NSLocalizedString("invalid_choices", comment: "Choices incomplete"), preferredStyle: .alert)
                
                alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default, handler: nil))
                
                _ = self.navigationController?.popToViewController(self, animated: true); // in case we are not the topViewController
                self.present(alertController, animated: true, completion: {
                    self.scrollToLastChoiceAndMakeFirstResponder()
                })
                
                return true; // invalid input handled
            }
        }
        return false; // no invalid input handled
    }
    
    func addChoice(interactive: Bool) {
        //tableView.beginUpdates()
        self.editableChoices.append(Choice(choiceText: ""))
        //tableView.endUpdates()
        if (interactive) {
            scrollToLastChoiceAndMakeFirstResponder()
        }
    }
    
    @IBAction func addChoiceAction(_ sender: UIButton) {
        self.addChoice(interactive: true)
    }
    
    @IBAction func removeChoiceAction(_ sender: UIButton) {
        
        if let clickedCell = sender.superview?.superview as? UITableViewCell {
            if let indexPath = tableView?.indexPath(for: clickedCell) {
                if (self.editableChoices.count > 1) {
                    let index = indexPath.row
                    
                    self.editableChoices.remove(at: index)
                    tableView?.reloadData()
                }
            }
        }
    }
    
    func appendDates(_ dates: [Date]){
        
        for date in dates{
            let dateString = Date.dateString(fromUnixTime: date.timeIntervalSince1970, weekDay: true)
            //            if let date_to = date.1 {
            //                dateString += " - " + NSDate.timeString(fromUnixTime: date_to.timeIntervalSince1970, weekDay: true)
            //            }
            
            let dateChoice = Choice(choiceText: dateString)
            dateChoice.date_from = date
            //            dateChoice.date_to = date.1
            
            self.editableChoices.append(dateChoice)
        }
        
        tableView?.reloadData()
        
    }
    
    func appendImages(_ images: [UIImage]){
        for image in images{
            let choice = Choice(choiceText: "")
            choice.picture = image
            choice.pictureString = ""
            
            let picture_small = image.resizeToWidth(500)
            let imageData = UIImageJPEGRepresentation(picture_small, 0.95)
            choice.pictureString = imageData?.base64EncodedString(options: .lineLength64Characters)
            
            self.editableChoices.append(choice)
        }
        tableView?.reloadData()
    }
    
}
