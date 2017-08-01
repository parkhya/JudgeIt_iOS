//
//  QuestionInviteController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 22/01/16.
//  Refactored by Dirk Theisen on 08/09/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation
import libPhoneNumber_iOS
import Adjust
import SwiftyJSON
import CoreTelephony
import Contacts
import MessageUI
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


class QuestionInviteController : UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, MFMessageComposeViewControllerDelegate {
    
    @IBOutlet var followupLabel: UILabel!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet var broadcastButton: UISwitch!
    @IBOutlet weak var publicButton: UISwitch!
    
    fileprivate var editQuestion: Question? // The question being edited
    var editQuestionParticipants: [User]?
    
    var contacts = [User]()
    var filteredContacts = [User]()
    var groups = [UserGroup]()
    var participatingGroups = Set<UserGroup>()
    var participatingUsers = Set<User>()
    var smsContacts = [PhoneContact]()
    var participatingSMSContacts = Set<PhoneContact>()
    var fixedParticipatingUsers = Set<User>()
    
    static let phoneRegion = { () -> String in
        let temp = CTTelephonyNetworkInfo().subscriberCellularProvider?.isoCountryCode ?? "DE"
        return temp.substring(to: temp.index(temp.startIndex, offsetBy: 2))
    }()
    let phoneUtil = NBPhoneNumberUtil()
    let phoneFormatter = NBAsYouTypeFormatter(regionCode: phoneRegion)
    
    func appendToContacts(_ new: Set<User>) {
        
        synced(lock: self){
            let contactsSet = Set(self.contacts).union(new)
            // Test, if elements were added:
            if contactsSet.count > self.contacts.count {
                // Sort contacts by putting participatingUsers first, then sort by username:
                self.contacts = contactsSet.sorted(by: { (u1, u2) -> Bool in
                    if self.fixedParticipatingUsers.contains(u1) && !self.fixedParticipatingUsers.contains(u2) {
                        return true
                    }
                    if self.fixedParticipatingUsers.contains(u2) && !self.fixedParticipatingUsers.contains(u1) {
                        return false
                    }
                    return u1.username.compare(u2.username, options: NSString.CompareOptions.caseInsensitive,
                                               range: nil, locale: nil) == .orderedAscending
                })
                tableView.reloadData()
            }
        }
    }
    
    func appendToGroups(_ new: Set<UserGroup>) {
        let groupsSet = Set(self.groups).union(new)
        // Test, if elements were added:
        if groupsSet.count > self.groups.count {
            // Sort contacts by putting participatingUsers first, then sort by username:
            self.groups = groupsSet.sorted(by: { (ug1, ug2) -> Bool in
                return ug1.title.compare(ug2.title, options: NSString.CompareOptions.caseInsensitive,
                                         range: nil, locale: nil) == .orderedAscending
            })
            tableView.reloadData()
        }
    }
    
    func reload(alsoCached: Bool = true) {
        
        //        self.contacts = []
        
        // Fetch all contacts...
        User.fetchContacts("users/\(GlobalQuestionData.user_id)", alsoCached: alsoCached) { (contacts, error) in
            if let contacts = contacts {
                
                // ...then, fetch all participatingUsers of editQuestion:
                if self.editQuestion != nil {
                    User.fetchUsers(questionId: self.editQuestion!.id, userId: nil) { (users, error) in
                        // Prefill participatingUsers:
                        if let users = users {
                            self.fixedParticipatingUsers = Set(users)
                            self.setParticipatingUsers(self.participatingUsers.union(self.fixedParticipatingUsers))
                            self.tableView.reloadData()
                        }
                    }
                }
                self.appendToContacts(Set(contacts))
                self.filteredContacts = self.contacts;
                
                if self.isSearchActive() {
                    self.filteredContacts = self.contacts.filter({$0.username.lowercased().range(of: self.searchBar.text!.lowercased()) != nil})
                }
                self.tableView.reloadData()
            }
            if error != nil {
                // TODO: Alert: (Retry | Abort)
            }
            
        }
        
        self.groups = []
        
        UserGroup.fetchUserGroups("users/\(GlobalQuestionData.user_id)", alsoCached: alsoCached) { (userGroups, error) in
            if let userGroups = userGroups {
                self.appendToGroups(Set(userGroups))
            }
        }
        
        UserGroup.fetchUserGroupMemberships("users/\(GlobalQuestionData.user_id)", alsoCached: alsoCached) { (userGroups, error) in
            if let userGroups = userGroups {
                self.appendToGroups(Set(userGroups))
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        searchBar.delegate = self
        
        // hack to remove empty table view cells:
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        
        broadcastButton.onTintColor = UIColor.judgeItPrimaryColor
        publicButton.onTintColor = UIColor.judgeItPrimaryColor
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        if let followedQuestion = self.questionEditController()?.followedQuestion {
            followupLabel.text = NSLocalizedString("followup_question", comment:"") + " " + followedQuestion.text
            followupLabel.isHidden = false
            
            User.fetchUsers(questionId: followedQuestion.id, userId: nil) { (users, error) in
                // Prefill participatingUsers:
                if let users = users {
                    self.setParticipatingUsers(Set(users))
                    self.tableView.reloadData()
                }
            }
        }
        
        self.reload()
        fetchPhoneContacts()
    }
    
    func fetchPhoneContacts(){
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
            
            let contactStore = CNContactStore()
            let requestedAttrs = [
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactPhoneNumbersKey,
                CNContactImageDataKey] as [Any]
            contactStore.requestAccess(for: .contacts, completionHandler: { (granted, error) -> Void in
                if granted {
                    let predicate = CNContact.predicateForContactsInContainer(withIdentifier: try! contactStore.containers(matching: nil).first!.identifier)
                    let contacts = try! contactStore.unifiedContacts(matching: predicate, keysToFetch: requestedAttrs as! [CNKeyDescriptor])
                    self.smsContacts = contacts.flatMap({ contact in
                        if let number = contact.phoneNumbers.first?.value {
                            let name = contact.givenName + " " + contact.familyName
                            let image = contact.imageData != nil ? UIImage(data: contact.imageData!) : nil
                            return PhoneContact(name: name, phoneNumber: number.stringValue, image: image)
                        }
                        return nil
                    })
                    self.smsContacts.sort(by: {$0.0.name.lowercased() < $0.1.name.lowercased()})
                    
                    self.tableView.reloadData()
                }
            })
        })
    }
    
    func setParticipatingUsers(_ newParticipatingUsers: Set<User>) {
        participatingUsers = newParticipatingUsers;
        self.appendToContacts(newParticipatingUsers)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        print("self.title = \(self.title)")
//        UserDefaults().set(self.title, forKey: "selectedClass")
//        UserDefaults().synchronize()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
//        UserDefaults().set(self.title, forKey: "selectedClass")
//        UserDefaults().synchronize()
        self.tableView.flashScrollIndicators()
    }
    
    func dismissKeyboard(){
        view.endEditing(true)
    }
    
    func passEditQuestion(_ question:Question) {
        
        self.editQuestion = question
        if self.view != nil && editQuestion != nil {
            reload()
        }
        
        self.validateUI()
    }
    
    //    @IBAction func contactsClicked(_ sender: UIButton) {
    //        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ContactsViewController") as! ContactsViewController
    //        viewController.shouldDisplayEditButton = false
    //        self.navigationController?.pushViewController(viewController, animated: true)
    //    }
    
    func isSearchActive() -> Bool {
        return searchBar.text?.length > 0
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredContacts = contacts.filter({$0.username.lowercased().range(of: searchText.lowercased()) != nil})
        if(searchText.length <= 0){
            filteredContacts = contacts
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.15 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
                self.view.endEditing(true)
            })
        }
        self.tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        if indexPath.section == 1 || isSearchActive() {
            if let userAtIndex = self.filteredContacts[safe: row] {
                if self.participatingUsers.contains(userAtIndex) {
                    self.setParticipatingUsers(self.participatingUsers.subtracting([userAtIndex]))
                } else {
                    self.setParticipatingUsers(self.participatingUsers.union([userAtIndex]))
                }
            }
        } else if indexPath.section == 0 {
            if let groupAtIndex = self.groups[safe: row] {
                if self.participatingGroups.contains(groupAtIndex) {
                    self.participatingGroups = self.participatingGroups.subtracting([groupAtIndex])
                } else {
                    self.participatingGroups = self.participatingGroups.union([groupAtIndex])
                }
            }
        } else {
            // Phone contact tapped
            if let phoneContact = self.smsContacts[safe: row] {
                if self.participatingSMSContacts.contains(phoneContact) {
                    self.participatingSMSContacts.remove(phoneContact)
                } else {
                    self.participatingSMSContacts.insert(phoneContact)
                    
                    self.broadcastButton.setOn(true, animated: true)
                }
            }
            
        }
        tableView.reloadData()
        tableView.deselectRow(at: indexPath, animated: false)
        self.searchBar.resignFirstResponder()
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsets.zero
        cell.layoutMargins = UIEdgeInsets.zero
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 || isSearchActive() {
            return filteredContacts.count
        } else if section == 0 {
            return groups.count
        } else {
            return smsContacts.count
        }
        
        //        if count == 0 {
        //            let view = UIView()
        //
        //            let messageLabel = UILabel(frame: CGRect(x: 25, y: 0, width: tableView.frame.width - 50, height: tableView.frame.height))
        //            messageLabel.text = NSLocalizedString("no_contacts_yet", comment: "")
        //            messageLabel.textAlignment = .center;
        //            messageLabel.font = UIFont.systemFont(ofSize: 16)
        //            messageLabel.numberOfLines = 0
        //
        //            view.addSubview(messageLabel)
        //            tableView.backgroundView = view
        //        } else {
        //            tableView.backgroundView = nil
        //        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if isSearchActive() {
            return 1
            //        } else if self.broadcastButton.isOn {
            //            return 3
        } else {
            //            return 2
            return 3
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if self.tableView(tableView, numberOfRowsInSection: section) == 0
            || isSearchActive(){
            return nil
        }
        if (section == 1 || isSearchActive()) {
            return makeTableViewHeaderView(title: NSLocalizedString("contacts_title", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "")
        } else  if section == 0 {
            // Groups Section
            return makeTableViewHeaderView(title: NSLocalizedString("groups_title", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "")
        } else {
            return makeTableViewHeaderView(title: NSLocalizedString("phone_title", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "")
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if self.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return 0.001
        }
        
        return 26
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if (indexPath.section == 1 || isSearchActive()) {
            if let user = filteredContacts[safe: indexPath.row], !self.fixedParticipatingUsers.contains(user) {
                return indexPath
            }
        } else {
            // Groups Section
            return indexPath
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if (indexPath.section == 1 || isSearchActive()) {
            if let user = filteredContacts[safe: indexPath.row], !self.fixedParticipatingUsers.contains(user) {
                return true
            }
        } else {
            return true
        }
        return false
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 1 || isSearchActive() {
            
            //        if searchController.active {
            //            let contactCell = tableView.dequeueReusableCellWithIdentifier("ContactCell") as! ContactTableViewCell
            //            if let user = searchResults[safe: indexPath.row] {
            //                contactCell.configure(user: user)
            //            }
            //            return contactCell
            //        } else {
            //            switch indexPath.section {
            //            case 0:
            //                let userGroupMembershipCell = tableView.dequeueReusableCellWithIdentifier("UserGroupMembershipCell") as! UserGroupMembershipTableViewCell
            //                if let userGroup = self.userGroupMemberships[safe: indexPath.row] {
            //                    userGroupMembershipCell.configure(userGroup: userGroup)
            //                }
            //                return userGroupMembershipCell
            //            case 1:
            //                let userGroupCell = tableView.dequeueReusableCellWithIdentifier("UserGroupCell") as! UserGroupTableViewCell
            //                if let userGroup = self.userGroups[safe: indexPath.row] {
            //                    userGroupCell.configure(userGroup: userGroup)
            //                }
            //                return userGroupCell
            //            case 2:
            let contactCell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as! ContactTableViewCell
            if let user = filteredContacts[safe: indexPath.row] {
                contactCell.configure(user: user)
                contactCell.accessoryType = self.participatingUsers.contains(user) ? UITableViewCellAccessoryType.checkmark : UITableViewCellAccessoryType.none
            }
            return contactCell
        } else if indexPath.section == 0 {
            // Groups Section
            let userGroupCell = tableView.dequeueReusableCell(withIdentifier: "UserGroupCell") as! UserGroupTableViewCell
            if let userGroup = self.groups[safe: indexPath.row] {
                userGroupCell.configure(userGroup: userGroup)
                userGroupCell.accessoryType = self.participatingGroups.contains(userGroup) ? UITableViewCellAccessoryType.checkmark : UITableViewCellAccessoryType.none
            }
            return userGroupCell
        } else {
            let contactCell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as! ContactTableViewCell
            if let phoneContact = smsContacts[safe: indexPath.row] {
                contactCell.configure(phoneContact: phoneContact)
                contactCell.accessoryType = self.participatingSMSContacts.contains(phoneContact) ? UITableViewCellAccessoryType.checkmark : UITableViewCellAccessoryType.none
                
            }
            return contactCell
            
        }
    }
    
    
    var _creationInProgress = false
    
    var indicatorView: UIActivityIndicatorView? = nil
    
    func showIndicator() {
        if indicatorView == nil {
            indicatorView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.white)
            if let indicatorView = indicatorView {
                indicatorView.frame = CGRect(x: 0.0, y: 0.0, width: 96.0, height: 96.0);
                indicatorView.backgroundColor = UIColor.darkGray
                indicatorView.alpha = 0.8
                indicatorView.layer.cornerRadius = 24
                indicatorView.center = self.view.center
                indicatorView.center.y -= (self.tabBarController?.tabBar.frame.height ?? 0) / 2
                self.view.addSubview(indicatorView)
                self.view.bringSubview(toFront: indicatorView)
            }
        }
        
        self.indicatorView?.startAnimating()
    }
    
    func hideIndicator() {
        indicatorView?.stopAnimating()
        indicatorView?.removeFromSuperview()
    }
    
    @IBAction func saveQuestion(_ sender: AnyObject) {
        self.view.resignFirstResponder()
        
        if !self.creationInProgress() {
            if self.editQuestion != nil {
                updateQuestion()
            } else {
                createNewQuestion()
            }
        }
    }
    
    func aggregatedParticipatingUsers() -> Set<User> {
        var allParticipatingUsers = self.participatingUsers
        for group in self.participatingGroups {
            allParticipatingUsers = allParticipatingUsers.union(group.memberList);
        }
        return allParticipatingUsers
    }
    
    func createNewQuestion() {
        
        //let addedParticipants = self.participatingUsers.subtract(self.fixedParticipatingUsers)
        let followupId = self.questionEditController()?.followedQuestion?.id
        
        if let questionEditController = self.questionEditController() {
            if (questionEditController.handleInvalidInput()) {
                self.navigationController?.popViewController(animated: true)
                return // do not validate self
            }
        }
        
        if (self.handleInvalidInput()) {
            return
        }
        
        // All input ok, create new question:
        
        self.setCreationInProgress (true);
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        let title: String = self.questionEditController()!.titleField2.text
        let choices: [Choice] = self.questionEditController()!.editableChoices
        let linkSharingAllowed = self.broadcastButton.isOn
        let isPublic = self.publicButton.isOn
        
        Question.createNew(text: title, choicesDictionaries: Choice.dictionariesFromChoices(choices), accessType: linkSharingAllowed ? 2 : 1,
                           isPublic: isPublic, followupQuestionId: followupId, completion: { (question, error) in
                            
                            if error != nil {
                                self.setCreationInProgress(false)
                                
                                let alertController = UIAlertController(title: NSLocalizedString("create_fail_title", comment: ""), message: NSLocalizedString("create_fail", comment: ""), preferredStyle: .alert)
                                
                                alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                                
                                self.present(alertController, animated: true, completion: nil)
                                return
                            }
                            
                            if(!isPublic){
                                _ = Comment.sendComment(question!.id, text: nil, photo: nil, created: 1, completion: {_,_ in })
                            }
                            
                            let allParticipatingUsers = self.aggregatedParticipatingUsers()
                            // Update question, by inviting allParticipatingUsers
                            let addedParticipantsDictionaries = User.dictionariesFromParticipants(allParticipatingUsers)
                            
                            User.addParticipants(questionId: question!.id,
                                                 participantsDictionaries: addedParticipantsDictionaries) { (users, error) in
                                                    self.setCreationInProgress(false);
                                                    
                                                    if (error != nil) {
                                                        print("Error adding participants: \(error.debugDescription) ")
                                                    }
                                                    
                                                    if linkSharingAllowed {
                                                        self.showBroadcastAlert(question!)
                                                    } else {
                                                        if let listVC = self.navigationController?.viewControllers.filter({$0 is VotingListViewController}).first {
                                                            
                                                            listVC.tabBarController?.selectedIndex = question!.isPublic ? 1 : 0
                                                            
                                                            if let navigationC = listVC.tabBarController?.viewControllers?.filter({$0.childViewControllers.contains(where: {$0 is PublicVotingListViewController})}).first as? JudgeitNavigationController,
                                                                let publicVC = navigationC.childViewControllers.filter({$0 is PublicVotingListViewController}).first as? PublicVotingListViewController, question!.isPublic {
                                                                publicVC.toggleShownVotings(ownOnly: true)
                                                            }
                                                            
                                                            if let navigationC = listVC.tabBarController?.viewControllers?.filter({$0.childViewControllers.contains(where: {$0 is PrivateVotingListController})}).first as? JudgeitNavigationController,
                                                                let privateVC = navigationC.childViewControllers.filter({$0 is PrivateVotingListController && !($0 is ChatListController)}).first as? PrivateVotingListController {
                                                                privateVC.toggleChatVotings(chat: false)
                                                            }
                                                        }
                                                        
                                                        _ = self.navigationController?.popToViewControllerOfClass(VotingListViewController.self, animated: true)
                                                        
                                                        if self.questionEditController()?.followedQuestion != nil {
                                                            _ = self.navigationController?.popViewController(animated: true)
                                                        }
                                                    }
                            }
                            NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
        })
        
        // Tracking:
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.low).async(execute: {
            // Voting created:
            Adjust.trackEvent(ADJEvent(eventToken: "42dnse"))
            
            // Adjust event: Voting is followup
            if self.questionEditController()?.followedQuestion != nil { Adjust.trackEvent(ADJEvent(eventToken: "u5zm11")) }
            
            // Adjust event: Voting is broadcast voting
            if linkSharingAllowed { Adjust.trackEvent(ADJEvent(eventToken: "5kf6j3")) }
            
            let withImages = choices.filter({$0.picture != nil})
            let withUrl = choices.filter({$0.url() != nil})
            
            // Adjust event: Voting contains images
            if withImages.count > 0 { Adjust.trackEvent(ADJEvent(eventToken: "vtt7kq")) }
            
            // voting contains links
            if withUrl.count > 0 { Adjust.trackEvent(ADJEvent(eventToken: "hp5e27")) }
            
            // text only question
            if withImages.count <= 0 && withUrl.count <= 0 { Adjust.trackEvent(ADJEvent(eventToken: "y0v515")) }
            
            // members per question
            for _ in self.participatingUsers { Adjust.trackEvent(ADJEvent(eventToken: "4283xi")) }
            
            // choices per question
            for _ in choices { Adjust.trackEvent(ADJEvent(eventToken: "rps5u0")) }
        })
    }
    
    //    class EditDelegate : EditTask.EditTaskDelegate {
    //
    //        var parent:QuestionInviteController
    //        let indicator:UIActivityIndicatorView
    //        let isBroadcast:Bool
    //        let question:Question
    //
    //        init(parent: QuestionInviteController, indicator:UIActivityIndicatorView, isBroadcast:Bool, question:Question){
    //            self.parent = parent
    //            self.indicator = indicator
    //            self.isBroadcast = isBroadcast
    //            self.question = question
    //        }
    //
    //        override func onPostExecute(result: Bool) {
    //            dispatch_async(dispatch_get_main_queue(), {
    //                self.indicator.removeFromSuperview()
    //                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    //
    //                if self.isBroadcast && result {
    //                    let shareUrl = "https://get.judge-it.net/broadcast/?share=1&ref=" + IDObfuscator.obfuscate(self.question.id.rawId()!)
    //                    let alert = UIAlertController(title: NSLocalizedString("broadcast_created_title", comment:""), message: NSLocalizedString("broadcast_created_congrats", comment: ""), preferredStyle: UIAlertControllerStyle.Alert)
    //                    alert.addTextFieldWithConfigurationHandler({textField in
    //                        textField.text = shareUrl
    //                        textField.enabled = false
    //                    })
    //
    //                    alert.addAction(UIAlertAction(title: NSLocalizedString("share_broadcast",comment:""), style: .Default, handler: { alertAction in
    //                        let username = GlobalQuestionData.userMap[GlobalQuestionData.user_id ?? -1]?.username ?? NSLocalizedString("someone", comment: "")
    //                        let appname = NSLocalizedString("app_name", comment: "")
    //                        let shareText = NSString(format: NSLocalizedString("share_text_broadcast", comment: ""), username, self.question.question_text, appname, appname, shareUrl) as String
    //
    //                        let activityViewController : UIActivityViewController = UIActivityViewController(
    //                            activityItems: [shareText], applicationActivities: nil)
    //                        activityViewController.completionWithItemsHandler = {activity, items, success, error in
    //                            self.parent.navigationController?.popViewControllerAnimated(true)
    //                        }
    //
    //                        // Anything you want to exclude
    //                        activityViewController.excludedActivityTypes = [
    //                            UIActivityTypePostToWeibo,
    //                            UIActivityTypePrint,
    //                            UIActivityTypeAssignToContact,
    //                            UIActivityTypeSaveToCameraRoll,
    //                            UIActivityTypeAddToReadingList,
    //                            UIActivityTypePostToFlickr,
    //                            UIActivityTypePostToVimeo,
    //                            UIActivityTypePostToTencentWeibo
    //                        ]
    //
    //                        self.parent.presentViewController(activityViewController, animated: true, completion: nil)
    //                    }))
    //
    //                    alert.addAction(UIAlertAction(title: NSLocalizedString("string_copy", comment: ""), style: .Default, handler: { alertAction in
    //                        let clipboard = UIPasteboard.generalPasteboard()
    //                        clipboard.string = shareUrl
    //
    //                        self.parent.navigationController?.popViewControllerAnimated(true)
    //                    }))
    //
    //                    self.parent.presentViewController(alert, animated: true, completion: nil)
    //                    //                } else if !result {
    //                } else {
    //                    self.parent.navigationController?.popViewControllerAnimated(true)
    //                }
    //            })
    //        }
    //    }
    
    func questionEditController() -> QuestionEditController? {
        if let prev = self.previousViewController() {
            if (prev.isKind(of: QuestionEditController.self)) {
                return prev as? QuestionEditController
            }
        }
        return nil;
    }
    
    
    func validateUI() {
        if self.view != nil {
            self.saveButton.isEnabled = !self.creationInProgress()
            
            if let followedQuestion = self.questionEditController()?.followedQuestion {
                followupLabel.text = NSLocalizedString("followup_question", comment: "") + " " + followedQuestion.text
                followupLabel.isHidden = false
            } else {
                followupLabel.isHidden = true
            }
            self.broadcastButton.isOn = (editQuestion?.isLinkSharingAllowed()) ?? self.broadcastButton.isOn
            
            self.publicButton.isOn = editQuestion?.isPublic ?? self.publicButton.isOn
        }
        //        self.broadcastButton.isHidden = editQuestion == nil
        self.publicButton.isEnabled = editQuestion == nil
        
    }
    
    func setCreationInProgress(_ yn: Bool) {
        if (yn) {
            self.showIndicator()
        } else {
            self.hideIndicator()
        }
        _creationInProgress = yn;
        UIApplication.shared.isNetworkActivityIndicatorVisible = _creationInProgress
        self.validateUI();
    }
    
    func creationInProgress() -> Bool {
        return _creationInProgress
    }
    
    func handleInvalidInput() -> Bool {
        let linkSharingAllowed:Bool = self.broadcastButton!.isOn
        let isPublic = self.publicButton.isOn
        
        if self.aggregatedParticipatingUsers().count <= 0 && !linkSharingAllowed && !isPublic {
            let alert = UIAlertView()
            alert.title = NSLocalizedString("few_members_title", comment: "Members incomplete - title")
            alert.message = NSLocalizedString("few_members", comment: "Members incomplete")
            alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK"))
            alert.show()
            return true
        }
        
        return false
    }
    
    @IBAction func broadcastToggled(_ sender: Any) {
        self.participatingSMSContacts.removeAll()
        
        self.tableView.reloadData()
    }
    
    func updateQuestion() {
        
        if (self.handleInvalidInput()) {
            return
        }
        
        // update question by changing access type:
        let linkSharingAllowed:Bool = self.broadcastButton.isOn
        
        if let editQuestion = self.editQuestion {
            if linkSharingAllowed != editQuestion.isLinkSharingAllowed() && !editQuestion.isLinkSharingAllowed() {
                Question.setAccessType(questionId: editQuestion.id, accessType: linkSharingAllowed ? 2 : 1, completion: { (success, error) in
                    // TODO: error handling
//                    if success {
//                        editQuestion.accessType = linkSharingAllowed ? 2 : 1
//                        
//                        let listVC = (AppDelegate.rootTabBarController?.viewControllers?.filter({vc in
//                            let listVC = (vc as? UINavigationController)?.viewControllers.first
//                            if editQuestion.isPublic {
//                                return listVC is PublicVotingListViewController
//                            } else if editQuestion.isChatOnly {
//                                return listVC is ChatListController
//                            } else {
//                                return listVC is PrivateVotingListController && !(listVC is ChatListController)
//                            }
//                        }).first as? UINavigationController)?.viewControllers.first as? VotingListViewController
//                        listVC?.reloadQuestions(forced: true)
//                    }
                })
            }
        }
        
        // Update question, by inviting new participatingUsers (users)
        // Substract all previous (fixed) users:
        var allParticipatingUsers = self.participatingUsers
        for group in self.participatingGroups {
            allParticipatingUsers = allParticipatingUsers.union(group.memberList);
        }
        
        let addedParticipants = allParticipatingUsers.subtracting(self.fixedParticipatingUsers)
        
        if (addedParticipants.count == 0  && !linkSharingAllowed) {
            // Nothing to do - shortcut
            _ = self.navigationController?.popViewController(animated: true)
            return
        }
        
        let addedParticipantsDictionaries = User.dictionariesFromParticipants(addedParticipants)
        
        self.setCreationInProgress(true);
        
        User.addParticipants(questionId: self.editQuestion!.id,
                             participantsDictionaries: addedParticipantsDictionaries) { (users, error) in
                                self.setCreationInProgress(false);
                                
                                if error == nil {
                                    if self.broadcastButton.isOn {
                                        let shareUrl = "https://get.judge-it.net/broadcast/?share=1&ref=" + IDObfuscator.obfuscate(self.editQuestion!.id.rawId()!)
                                        let alert = UIAlertController(title: NSLocalizedString("broadcast_created_title", comment:""), message: NSLocalizedString("broadcast_created_congrats", comment: ""), preferredStyle: UIAlertControllerStyle.alert)
                                        alert.addTextField(configurationHandler: {textField in
                                            textField.text = shareUrl
                                            textField.isEnabled = false
                                        })
                                        
                                        alert.addAction(UIAlertAction(title: NSLocalizedString("share_broadcast",comment:""), style: .default, handler: { alertAction in
                                            let username = GlobalQuestionData.userMap[GlobalQuestionData.user_id]?.username ?? NSLocalizedString("someone", comment: "")
                                            let appname = NSLocalizedString("app_name", comment: "")
                                            let shareText = NSString(format: NSLocalizedString("share_text_broadcast", comment: "") as NSString, username, self.editQuestion!.text, appname, appname, shareUrl) as String
                                            
                                            let activityViewController : UIActivityViewController = UIActivityViewController(
                                                activityItems: [shareText], applicationActivities: nil)
                                            activityViewController.completionWithItemsHandler = {activity, items, success, error in
                                                _ = self.navigationController?.popViewController(animated: true)
                                            }
                                            
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
                                        }))
                                        
                                        alert.addAction(UIAlertAction(title: NSLocalizedString("string_copy", comment: ""), style: .default, handler: { alertAction in
                                            let clipboard = UIPasteboard.general
                                            clipboard.string = shareUrl
                                            
                                            _ = self.navigationController?.popViewController(animated: true)
                                        }))
                                        
                                        self.present(alert, animated: true, completion: nil)
                                    } else {
                                        _ = self.navigationController?.popViewController(animated: true)
                                    }
                                    
                                    //Adjust event: members invited
                                    if addedParticipants.count > 0 {
                                        Adjust.trackEvent(ADJEvent(eventToken: "c1farj"))
                                    }
                                    
                                    if !self.editQuestion!.isPublic,
                                        let users = (users as? Array<[String : Any]>) {
                                        for user in users {
                                            if let user_id = (user["participant-id"] as? String)?.rawId(){
                                                _ = Comment.sendComment(self.editQuestion!.id, text: nil, photo: nil, join: [user_id], completion: {_,_ in })
                                            }
                                        }
                                    }
                                }
                                NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
                                
                                
        }
    }
    
    func showBroadcastAlert(_ question: Question) {
        let shareUrl = "https://get.judge-it.net/broadcast/?share=1&ref=" + IDObfuscator.obfuscate(question.id.rawId()!)
        let alert = UIAlertController(title: NSLocalizedString("broadcast_created_title", comment:""), message: NSLocalizedString("broadcast_created_congrats", comment: ""), preferredStyle: UIAlertControllerStyle.alert)
        alert.addTextField(configurationHandler: {textField in
            textField.text = shareUrl
            textField.isEnabled = false
        })
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("share_broadcast",comment:""), style: .default, handler: { alertAction in
            let username = GlobalQuestionData.userMap[GlobalQuestionData.user_id]?.username ?? NSLocalizedString("someone", comment: "")
            let appname = NSLocalizedString("app_name", comment: "")
            let shareText = NSString(format: NSLocalizedString("share_text_broadcast", comment: "") as NSString, username, question.text, appname, appname, shareUrl) as String
            
            let activityViewController : UIActivityViewController = UIActivityViewController(
                activityItems: [shareText], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view
            activityViewController.completionWithItemsHandler = {_,_,_,_ in
                
                if let listVC = self.navigationController?.viewControllers.filter({$0 is VotingListViewController}).first {
                    
                    listVC.tabBarController?.selectedIndex = question.isPublic ? 1 : 0
                    
                    if let navigationC = listVC.tabBarController?.viewControllers?.filter({$0.childViewControllers.contains(where: {$0 is PublicVotingListViewController})}).first as? JudgeitNavigationController,
                        let publicVC = navigationC.childViewControllers.filter({$0 is PublicVotingListViewController}).first as? PublicVotingListViewController, question.isPublic {
                        publicVC.toggleShownVotings(ownOnly: false)
                    }
                    
                    if let navigationC = listVC.tabBarController?.viewControllers?.filter({$0.childViewControllers.contains(where: {$0 is PrivateVotingListController})}).first as? JudgeitNavigationController,
                        let privateVC = navigationC.childViewControllers.filter({$0 is PrivateVotingListController && !($0 is ChatListController)}).first as? PrivateVotingListController {
                        privateVC.toggleChatVotings(chat: false)
                    }
                }
                
                _ = self.navigationController?.popToViewControllerOfClass(VotingListViewController.self, animated: true)
                
                //                self.navigationController?.popViewControllerAnimated(true)
                //
                //                if self.editQuestion!.isFollowup() {
                //                    self.navigationController?.popViewControllerAnimated(true)
                //                }
            }
            
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
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("string_copy", comment: ""), style: .default, handler: { alertAction in
            let clipboard = UIPasteboard.general
            clipboard.string = shareUrl
            
            if let listVC = self.navigationController?.viewControllers.filter({$0 is VotingListViewController}).first {
                
                listVC.tabBarController?.selectedIndex = question.isPublic ? 1 : 0
                
                if let navigationC = listVC.tabBarController?.viewControllers?.filter({$0.childViewControllers.contains(where: {$0 is PublicVotingListViewController})}).first as? JudgeitNavigationController,
                    let publicVC = navigationC.childViewControllers.filter({$0 is PublicVotingListViewController}).first as? PublicVotingListViewController, question.isPublic {
                    publicVC.toggleShownVotings(ownOnly: true)
                }
                
                if let navigationC = listVC.tabBarController?.viewControllers?.filter({$0.childViewControllers.contains(where: {$0 is PrivateVotingListController})}).first as? JudgeitNavigationController,
                    let privateVC = navigationC.childViewControllers.filter({$0 is PrivateVotingListController && !($0 is ChatListController)}).first as? PrivateVotingListController {
                    privateVC.toggleChatVotings(chat: false)
                }
            }
            
            _ = self.navigationController?.popToViewControllerOfClass(VotingListViewController.self, animated: true)
        }))
        
        if self.participatingSMSContacts.count > 0 {
            let controller = MFMessageComposeViewController()
            
            let username = GlobalQuestionData.userMap[GlobalQuestionData.user_id]?.username ?? NSLocalizedString("someone", comment: "")
            let appname = NSLocalizedString("app_name", comment: "")
            let shareText = NSString(format: NSLocalizedString("share_text_broadcast", comment: "") as NSString, username, question.text, appname, appname, shareUrl) as String
            controller.body = shareText
            
            controller.recipients = participatingSMSContacts.map({$0.phoneNumber})
            controller.messageComposeDelegate = self
            
            broadcastViewController = alert
            
            self.present(controller, animated: true, completion: nil)
        }else {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    var broadcastViewController:UIAlertController? = nil
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: {
            if let alert = self.broadcastViewController {
                self.present(alert, animated: true, completion: nil)
            }
        })
    }
    
    func synced(lock: AnyObject, closure: () -> ()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
}
