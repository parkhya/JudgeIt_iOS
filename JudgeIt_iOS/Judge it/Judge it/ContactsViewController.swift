//
//  ContactsViewController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 10/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import Adjust
import Contacts

class ContactsViewController : UITableViewController, UISearchResultsUpdating, UISearchControllerDelegate {
    
    let searchController = UISearchController(searchResultsController: nil) // use existing TableView
    var searchBar: UISearchBar!
    @IBOutlet weak var addButton: UIBarButtonItem!
    
    var shouldDisplayEditButton = true
    
    var contacts = [User]()
    var userGroups = [UserGroup]()
    var userGroupMemberships = [UserGroup]()
    var blockedContacts = [User]()
    var phoneContacts = [PhoneContact]()
    
    var searchResults = [User]()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.localizeStrings()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(newDataDidBecomeAvailable), name: NSNotification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
        
        self.definesPresentationContext = true
        
        //        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        //        tap.cancelsTouchesInView = false
        //        view.addGestureRecognizer(tap)
    }
    
    func newDataDidBecomeAvailable() {
        self.reload(alsoCached: false)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func reload(alsoCached: Bool = true) {
        User.fetchContacts("users/\(GlobalQuestionData.user_id)", alsoCached: alsoCached) { (contacts, error) in
            if let contacts = contacts {
                self.contacts = contacts.filter({$0.relation != .BLACKLIST})
                self.blockedContacts = contacts.filter({$0.relation == .BLACKLIST})
                self.tableView.reloadData()
            }
        }
        
        UserGroup.fetchUserGroups("users/\(GlobalQuestionData.user_id)", alsoCached: alsoCached) { (userGroups, error) in
            if let userGroups = userGroups {
                self.userGroups = userGroups
                self.tableView.reloadData()
            }
        }
        
        UserGroup.fetchUserGroupMemberships("users/\(GlobalQuestionData.user_id)", alsoCached: alsoCached) { (userGroups, error) in
            if let userGroups = userGroups {
                self.userGroupMemberships = userGroups
                self.tableView.reloadData()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if shouldDisplayEditButton {
            self.navigationItem.leftBarButtonItems = [editButtonItem]
            self.navigationItem.leftBarButtonItem!.image = UIImage(named: "ic_edit")
            self.navigationItem.leftBarButtonItem!.title = ""
        }
        
        searchBar = searchController.searchBar
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.delegate = self
        searchController.searchBar.placeholder = NSLocalizedString("search_new_contacts", comment: "")
        self.tableView.tableHeaderView = searchBar
        
        reload()
        fetchPhoneContacts()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.searchController.isActive = false // dismiss search
        self.searchController.removeFromParentViewController()
        
        super.viewWillDisappear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "Contacts")
        tracker?.send(GAIDictionaryBuilder.createScreenView().build() as NSDictionary? as! [AnyHashable: Any])
        
        User.addMatchingPhoneContacts { (addedContactUserIds, error) in
            if let userIds = addedContactUserIds {
                if userIds.count > 0 {
                    self.reload()
                }
            }
        }
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: Table View
    override func numberOfSections(in tableView: UITableView) -> Int {
        if searchController.isActive {
            return 1
        }
        return 5
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchController.isActive {
            return searchResults.count
        }
        
        switch section {
        case 0:
            return self.userGroupMemberships.count
        case 1:
            return self.userGroups.count
        case 2:
            return self.contacts.count
        case 3:
            return self.blockedContacts.count
        case 4:
            return self.phoneContacts.count
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if self.tableView(tableView, numberOfRowsInSection: section) == 0
            || searchController.isActive {
            return nil
        }
        
        switch section {
        case 0:
            return makeTableViewHeaderView(title: NSLocalizedString("member_of_groups_title", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "AmaticSC-Regular")
        case 1:
            return makeTableViewHeaderView(title: NSLocalizedString("my_groups_title", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "AmaticSC-Regular")
        case 2:
            return makeTableViewHeaderView(title: NSLocalizedString("contacts_title", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "AmaticSC-Regular")
        case 3:
            return makeTableViewHeaderView(title: NSLocalizedString("string_blocked", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "AmaticSC-Regular")
        case 4:
            return makeTableViewHeaderView(title: NSLocalizedString("phone_title", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "AmaticSC-Regular")
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if self.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return 0.001
        }
        
        return 26
    }
    
    //    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    //
    //        if self.tableView(tableView, numberOfRowsInSection: section) == 0
    //        || searchController.active {
    //            return nil
    //        }
    //
    //        switch section {
    //        case 0:
    //            return NSLocalizedString("member_of_groups_title", comment: "")
    //        case 1:
    //            return NSLocalizedString("my_groups_title", comment: "")
    //        case 2:
    //            return NSLocalizedString("contacts_title", comment: "")
    //        default:
    //            return ""
    //        }
    //    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if searchController.isActive {
            let contactCell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as! ContactTableViewCell
            if let user = searchResults[safe: indexPath.row] {
                contactCell.configure(user: user)
            }
            return contactCell
        } else {
            switch indexPath.section {
            case 0:
                let userGroupMembershipCell = tableView.dequeueReusableCell(withIdentifier: "UserGroupMembershipCell") as! UserGroupMembershipTableViewCell
                if let userGroup = self.userGroupMemberships[safe: indexPath.row] {
                    userGroupMembershipCell.configure(userGroup: userGroup)
                }
                return userGroupMembershipCell
            case 1:
                let userGroupCell = tableView.dequeueReusableCell(withIdentifier: "UserGroupCell") as! UserGroupTableViewCell
                if let userGroup = self.userGroups[safe: indexPath.row] {
                    userGroupCell.configure(userGroup: userGroup)
                }
                return userGroupCell
            case 2:
                let contactCell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as! ContactTableViewCell
                if let user = contacts[safe: indexPath.row] {
                    contactCell.configure(user: user)
                }
                return contactCell
            case 3:
                let contactCell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as! ContactTableViewCell
                if let user = blockedContacts[safe: indexPath.row] {
                    contactCell.configure(user: user)
                }
                return contactCell
            case 4:
                let cell = tableView.dequeueReusableCell(withIdentifier: "PhoneContactCell")!
                if let phoneContact = self.phoneContacts[safe: indexPath.row] {
                    let nameLabel = cell.viewWithTag(101) as! UILabel
                    nameLabel.text = phoneContact.name
                    
                    let phoneNumberLabel = cell.viewWithTag(102) as! UILabel
                    phoneNumberLabel.text = phoneContact.phoneNumber
                    
                    let pictureView = cell.viewWithTag(100) as! UIImageView
                    pictureView.image = phoneContact.image
                    
                    let inviteButton = cell.viewWithTag(103) as! UILabel
                    
                    //                    if(phoneContact.1){
                    //                        inviteButton.backgroundColor = UIColor.clearColor()
                    //                        inviteButton.text = NSLocalizedString("invite_sent", comment: "")
                    //                    } else{
                    inviteButton.backgroundColor = UIColor.judgeItPrimaryColor
                    inviteButton.text = NSLocalizedString("invite_button", comment: "")
                    
                    let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(phoneInviteTapped(_:)))
                    inviteButton.isUserInteractionEnabled = true
                    inviteButton.addGestureRecognizer(tapGestureRecognizer)
                    //                    }
                    
                }
                cell.selectionStyle = .none
                
                return cell
            default:
                return UITableViewCell(frame: CGRect.null)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        view.tintColor = UIColor.white
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        //        let user = contacts[safe: indexPath.row] as? User
        //        if(user?.relation == .BLACKLIST){
        //            let title:String? = NSLocalizedString( "unblock_user", comment:"")
        //            let editAction = UITableViewRowAction(style: .Default, title: title, handler: {rowAction, editIndexPath in
        //                self.tableView(tableView, commitEditingStyle: .Delete, forRowAtIndexPath: editIndexPath)
        //            })
        //            editAction.backgroundColor = user?.relation == .BLACKLIST ? UIColor.grayColor() : UIColor.redColor()
        //
        //            return [editAction]
        //        }
        return nil
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        self.navigationItem.leftBarButtonItem!.title = ""
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return indexPath.section != 4 ? .delete : .none
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            switch indexPath.section {
            case 0:
                if let userGroupMembership = self.userGroupMemberships[safe: indexPath.row] {
                    userGroupMembership.removeMembers(memberIds: ["users/\(GlobalQuestionData.user_id)"]) { (error) in
                        if error == nil {
                            self.reload()
                        }
                    }
                }
                break
            case 1:
                if let userGroup = self.userGroups[safe: indexPath.row] {
                    userGroup.deleteGroup({ (error) in
                        if error == nil {
                            self.reload()
                        }
                    })
                }
                break
            case 2:
                if let contact = contacts[safe: indexPath.row] {
                    User.removeFromContacts(userIds: [contact.id()], completion: { (error) in
                        if error == nil {
                            self.reload()
                        }
                    })
                }
                break;
            case 3:
                if let contact = blockedContacts[safe: indexPath.row] {
                    User.removeFromContacts(userIds: [contact.id()], completion: { (error) in
                        if error == nil {
                            self.reload()
                        }
                    })
                }
                break;
            default:
                break
            }
        }
    }
    
    func editUserGroup(_ userGroup: UserGroup, isNewGroup: Bool = false) {
        let groupEditController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "GroupEditController") as! GroupEditController
        
        groupEditController.contacts = self.contacts.sorted(by: {user1, user2 in
            let user1InGroup = userGroup.memberList.contains(user1)
            let user2InGroup = userGroup.memberList.contains(user2)
            if(user1InGroup != user2InGroup){
                return user1InGroup && !user2InGroup
            }
            return user1.username.lowercased() < user2.username.lowercased()
        })
        groupEditController.userGroup = userGroup
        groupEditController.isNewGroup = isNewGroup
        
        self.navigationItem.backBarButtonItem?.title = NSLocalizedString("cancel", comment: "")
        // TODO: Present this ViewController modally, so "Cancel" gives the user the right intuition on what happens.
        self.navigationController?.pushViewController(groupEditController, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(indexPath.section == 4){
            return
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        if searchController.isActive {
            if let user = searchResults[safe: indexPath.row], !contacts.contains(user) {
                User.addToContacts(userIds: [user.id()], relationType: .FRIEND) { (error) in
                    if error == nil {
                        self.searchController.isActive = false // dismiss search
                        Adjust.trackEvent(ADJEvent(eventToken: "a0mhyj"))
                        self.reload()
                    }
                }
            }
            return
        }
        
        switch indexPath.section {
        case 0:
            if let userGroupMembership = self.userGroupMemberships[safe: indexPath.row] {
                let infoController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "UserInfoController") as! UserInfoController
                infoController.set(userGroup: userGroupMembership)
                
                let height = NSLayoutConstraint(item: infoController.view, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: self.view.frame.height * 0.50)
                infoController.view.addConstraint(height);
                
                let userAlert = UIAlertController(title: "", message: nil, preferredStyle: UIAlertControllerStyle.alert)
                userAlert.setValue(infoController, forKey: "contentViewController")
                userAlert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .default, handler: { alertAction in
                    self.reload()
                }))
                
                self.present(userAlert, animated: true, completion: nil)
            }
            break
        case 1:
            if let userGroup = self.userGroups[safe: indexPath.row] {
                self.editUserGroup(userGroup)
            }
            break
        case 2:
            if let contact = self.contacts[safe: indexPath.row] {
                let infoController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "UserInfoController") as! UserInfoController
                infoController.set(user: contact)
                
                let userAlert = UIAlertController(title: "", message: nil, preferredStyle: UIAlertControllerStyle.alert)
                userAlert.setValue(infoController, forKey: "contentViewController")
                userAlert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .default, handler: { alertAction in
                    self.reload()
                }))
                
                self.present(userAlert, animated: true, completion: nil)
            }
            break
        case 3:
            if let contact = self.blockedContacts[safe: indexPath.row] {
                let infoController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "UserInfoController") as! UserInfoController
                infoController.set(user: contact)
                
                let userAlert = UIAlertController(title: "", message: nil, preferredStyle: UIAlertControllerStyle.alert)
                userAlert.setValue(infoController, forKey: "contentViewController")
                userAlert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .default, handler: { alertAction in
                    self.reload()
                }))
                
                self.present(userAlert, animated: true, completion: nil)
            }
            break
        default:
            break
        }
    }
    
    func willPresentSearchController(_ searchController: UISearchController) {
        self.navigationController?.navigationBar.isTranslucent = true
        self.addButton.isEnabled = false
        self.navigationItem.leftBarButtonItem!.image = nil
        self.navigationItem.leftBarButtonItem!.title = ""
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        self.navigationController?.navigationBar.isTranslucent = false
        self.addButton.isEnabled = true
        if self.shouldDisplayEditButton {
            self.navigationItem.leftBarButtonItems = [editButtonItem]
            self.navigationItem.leftBarButtonItem!.image = UIImage(named: "ic_edit")
            self.navigationItem.leftBarButtonItem!.title = ""
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchString = searchController.searchBar.text ?? ""
        if searchString.length >= 2  {
            User.searchUsers(term: "name:%\(searchString)%", completion: { (users, error) in
                if self.searchController.searchBar.text == searchString {
                    if let users = users {
                        self.searchResults = users
                        self.tableView.reloadData()
                    }
                }
            })
        } else {
            self.searchResults = []
            self.tableView.reloadData()
        }
    }
    
    @IBAction func addGroup(_ sender: AnyObject) {
        self.addButton.isEnabled = false
        
        let userGroup = UserGroup(group_id: -1, creator_id: GlobalQuestionData.user_id, groupName: "", memberList: [], picturePath: nil)
        self.editUserGroup(userGroup, isNewGroup: true)
        
        self.addButton.isEnabled = true
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
                    self.phoneContacts = contacts.flatMap({ contact in
                        if let number = contact.phoneNumbers.first?.value {
                            let name = contact.givenName + " " + contact.familyName
                            let image = contact.imageData != nil ? UIImage(data: contact.imageData!) : nil
                            return PhoneContact(name: name, phoneNumber: number.stringValue, image: image)
                        }
                        return nil
                    })
                    self.phoneContacts.sort(by: {$0.0.name.lowercased() < $0.1.name.lowercased()})
                    
                    self.tableView.reloadData()
                }
            })
        })
    }
    
    func phoneInviteTapped(_ sender: UITapGestureRecognizer){
        let inviteButton = sender.view as! UILabel
        
        if let clickedCell = inviteButton.superview?.superview as? UITableViewCell,
            let indexPath = tableView.indexPath(for: clickedCell),
            let phoneNumber = phoneContacts[safe: indexPath.row]?.phoneNumber {
            
            let formattedNumber = phoneNumber.replacingOccurrences(of: "+", with: "00").removeWhitespace()
            let message = "sms:\(formattedNumber)&body=\(NSString(format: NSLocalizedString("imessage_invite", comment: "") as NSString, "https://judge-it.net"))"
            
            let messageURL = URL(string: message.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)!
            UIApplication.shared.openURL(messageURL)
        }
    }
    
}
