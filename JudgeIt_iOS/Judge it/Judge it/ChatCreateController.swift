//
//  ChatCreateController.swift
//  Judge it!
//
//  Created by Daniel Theveßen on 17/03/2017.
//  Copyright © 2017 Judge it. All rights reserved.
//

import Foundation
import UIKit

class ChatCreateController : UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var chatIcon: UIImageView!
    var newPhoto:UIImage? = nil
    lazy var imagePicker = UIImagePickerController()
    @IBOutlet weak var titleField: UITextField!
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    var contacts = [User]()
    var filteredContacts = [User]()
    var groups = [UserGroup]()
    var participatingGroups = Set<UserGroup>()
    var participatingUsers = Set<User>()
    var fixedParticipatingUsers = Set<User>()
    
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
        
        let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(imageSelected))
        chatIcon.isUserInteractionEnabled = true
        chatIcon.addGestureRecognizer(tapGestureRecognizer)
        
        chatIcon.layer.borderWidth = 1.0
        chatIcon.layer.masksToBounds = false
        chatIcon.layer.borderColor = UIColor.white.cgColor
        chatIcon.layer.cornerRadius = chatIcon.frame.size.width/2
        chatIcon.clipsToBounds = true
        
        imagePicker.delegate = self
        
        // hack to remove empty table view cells:
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        self.reload()
    }
    
    func setParticipatingUsers(_ newParticipatingUsers: Set<User>) {
        participatingUsers = newParticipatingUsers;
        self.appendToContacts(newParticipatingUsers)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.tabBarController?.tabBar.isHidden = true
        
        super.viewDidAppear(animated)
        
        self.tableView.flashScrollIndicators()
    }
    
    func dismissKeyboard(){
        view.endEditing(true)
    }
    
//    @IBAction func contactsClicked(_ sender: UIButton) {
//        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ContactsViewController") as! ContactsViewController
//        viewController.shouldDisplayEditButton = false
//        self.navigationController?.pushViewController(viewController, animated: true)
//    }
    
    func isSearchActive() -> Bool {
        return (searchBar.text?.length ?? 0) > 0
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredContacts = contacts.filter({$0.username.lowercased().range(of: searchText.lowercased()) != nil})
        if(searchText.length <= 0){
            filteredContacts = contacts
        }
        self.tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        if indexPath.section == 0 && !isSearchActive() {
            if let groupAtIndex = self.groups[safe: row] {
                if self.participatingGroups.contains(groupAtIndex) {
                    self.participatingGroups = self.participatingGroups.subtracting([groupAtIndex])
                } else {
                    self.participatingGroups = self.participatingGroups.union([groupAtIndex])
                }
            }
        } else {
            if let userAtIndex = self.filteredContacts[safe: row] {
                if self.participatingUsers.contains(userAtIndex) {
                    self.setParticipatingUsers(self.participatingUsers.subtracting([userAtIndex]))
                } else {
                    self.setParticipatingUsers(self.participatingUsers.union([userAtIndex]))
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
        let count = section == 1 || isSearchActive() ?  filteredContacts.count : groups.count
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
        return count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearchActive() ? 1 : 2
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if self.tableView(tableView, numberOfRowsInSection: section) == 0
            || isSearchActive()
        {
            return nil
        }
        if (section == 1 || isSearchActive()) {
            return makeTableViewHeaderView(title: NSLocalizedString("contacts_title", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "")
        } else {
            // Groups Section
            return makeTableViewHeaderView(title: NSLocalizedString("groups_title", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "")
        }
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
            let contactCell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as! ContactTableViewCell
            if let user = filteredContacts[safe: indexPath.row] {
                contactCell.configure(user: user)
                contactCell.accessoryType = self.participatingUsers.contains(user) ? UITableViewCellAccessoryType.checkmark : UITableViewCellAccessoryType.none
                
            }
            return contactCell
        } else {
            // Groups Section
            let userGroupCell = tableView.dequeueReusableCell(withIdentifier: "UserGroupCell") as! UserGroupTableViewCell
            if let userGroup = self.groups[safe: indexPath.row] {
                userGroupCell.configure(userGroup: userGroup)
                userGroupCell.accessoryType = self.participatingGroups.contains(userGroup) ? UITableViewCellAccessoryType.checkmark : UITableViewCellAccessoryType.none
            }
            return userGroupCell
        }
    }
    
    func imageSelected(_ sender:AnyObject){
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
        
        alert.popoverPresentationController?.sourceView = chatIcon
        
        present(alert, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerEditedImage] as? UIImage ?? info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            
            self.chatIcon.image = pickedImage
            self.chatIcon.contentMode = .scaleAspectFill
            
            self.newPhoto = pickedImage
        }
        
        dismiss(animated: true, completion: nil)
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
        
        createNewQuestion()
    }
    
    func aggregatedParticipatingUsers() -> Set<User> {
        var allParticipatingUsers = self.participatingUsers
        for group in self.participatingGroups {
            allParticipatingUsers = allParticipatingUsers.union(group.memberList);
        }
        return allParticipatingUsers
    }
    
    func createNewQuestion() {
        
        if (self.handleInvalidInput()) {
            return
        }
        
        // All input ok, create new question:
        self.setCreationInProgress (true)
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        var title = "Chat"
        if let text = self.titleField.text, text.trim().length > 0 {
            title = text
        } else if self.participatingGroups.count == 1 && self.participatingUsers.count == 0 {
            title = self.participatingGroups.first!.title
        } else if self.participatingGroups.count == 0 && self.participatingUsers.count == 1 {
            title = self.participatingUsers.first!.username
        }
        
        // Set photo to group picture if no custom icon was selected
        let groupPhotoDispatchGroup = DispatchGroup()
        groupPhotoDispatchGroup.enter()
        if self.participatingGroups.count == 1 && self.participatingUsers.count == 0 && newPhoto == nil,
            let group = self.participatingGroups.first,
            group.photoId != nil {
            group.fetchPhoto({image, error in
                if let image = image {
                    self.newPhoto = image
                }
                groupPhotoDispatchGroup.leave()
            })
        } else {
            groupPhotoDispatchGroup.leave()
        }
        
        groupPhotoDispatchGroup.notify(queue: DispatchQueue.main, execute: {
            var choices = [[String:Any]]()
            if let icon = self.newPhoto {
                let choice = Choice(choiceText: "")
                choice.picture = icon
                
                let picture_small = icon.resizeToWidth(500)
                let imageData = UIImageJPEGRepresentation(picture_small, 0.95)
                choice.pictureString = imageData?.base64EncodedString(options: .lineLength64Characters)
                
                choices = Choice.dictionariesFromChoices([choice])
            }
            
            Question.createNew(text: title, choicesDictionaries: choices, chatOnly: true, completion: { (question, error) in
                
                if error != nil {
                    self.setCreationInProgress(false)
                    
                    let alertController = UIAlertController(title: NSLocalizedString("create_fail_title", comment: ""), message: NSLocalizedString("create_fail", comment: ""), preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                    return
                }
                
                _ = Comment.sendComment(question!.id, text: nil, photo: nil, created: 1, completion: {_,_ in })
                
                let allParticipatingUsers = self.aggregatedParticipatingUsers()
                // Update question, by inviting allParticipatingUsers
                let addedParticipantsDictionaries = User.dictionariesFromParticipants(allParticipatingUsers)
                
                User.addParticipants(questionId: (question?.id)!, participantsDictionaries: addedParticipantsDictionaries) { (users, error) in
                    self.setCreationInProgress(false)
                    
                    if (error != nil) {
                        print("Error adding participants: \(error.debugDescription) ")
                    }
                    
//                    if let listVC = self.navigationController?.viewControllers.filter({$0 is VotingListViewController}).first,
//                        let navigationC = listVC.tabBarController?.viewControllers?.filter({$0.childViewControllers.contains(where: {$0 is PrivateVotingListController})}).first,
//                        let privateVC = navigationC.childViewControllers.filter({$0 is PrivateVotingListController}).first as? PrivateVotingListController {
//                        privateVC.tabBarController?.selectedIndex = 2
//                        privateVC.toggleChatVotings(chat: true)
//                    }
                    
                    _ = self.navigationController?.popToViewControllerOfClass(VotingListViewController.self, animated: true)
                }
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
            })
        })
        
    }
    
    func validateUI() {
        if self.view != nil {
            self.saveButton.isEnabled = !self.creationInProgress()
        }
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
        if self.aggregatedParticipatingUsers().count <= 0 {
            let alert = UIAlertView()
            alert.title = NSLocalizedString("few_members_title", comment: "Members incomplete - title")
            alert.message = NSLocalizedString("few_members", comment: "Members incomplete")
            alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK"))
            alert.show()
            return true
        }
        
        return false
    }
    
    func synced(lock: AnyObject, closure: () -> ()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
}
