//
//  UserViewController.swift
//  Judge it!
//
//  Created by Daniel Thevessen on 30/06/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

// CAUTION: Shows details of a user or a user group (despite of the name)

import Foundation
import UIKit
import Adjust

class UserInfoController : UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var userImageView: UIImageView!
    @IBOutlet weak var userName: UILabel!
    
    // user-specific
    @IBOutlet weak var statusText: UILabel!
    @IBOutlet weak var contactsButton: UIButton!
    @IBOutlet var contactsButtonHeight: NSLayoutConstraint!
    @IBOutlet var blockButton: UIButton!
    @IBOutlet var blockButtonHeight: NSLayoutConstraint!
    
    // group-specific
    @IBOutlet weak var groupTableView: UITableView!
    @IBOutlet weak var groupTableHeight: NSLayoutConstraint!
    
    fileprivate var user: User?
    fileprivate var userGroup: UserGroup?
    fileprivate var userGroupMembers: [User]?
    
    func set(user: User) {
        self.user = user
        
        if self.view != nil {
            self.userImageView.image = nil
            user.fetchPhoto({ (image, error) in
                self.userImageView.image = image
            })
            
            groupTableView.isHidden = true
            groupTableHeight.constant = 0
            
            self.userName.text = user.username
            self.statusText.text = user.statusText
            
            if user.user_id == GlobalQuestionData.user_id {
                self.contactsButtonHeight.constant = 0
                contactsButton.isHidden = true
                
                blockButtonHeight.constant = 0
                blockButton.isHidden = true
            } else {
                self.contactsButton.addTarget(self, action: #selector(UserInfoController.flipContact), for: .touchUpInside)
                self.blockButton.addTarget(self, action: #selector(UserInfoController.blockUser), for: .touchUpInside)
            }
            
            self.validateUI()
            
            // TODO: not used for now because of inconsistent behavior atm
            //            blockButtonHeight.constant = 0
            //            blockButton.hidden = true
            blockButton.setNeedsDisplay()
            blockButton.setNeedsLayout()
            blockButton.layoutIfNeeded()
            
            if user.relation == ContactRelation.BLACKLIST {
                blockButton.tintColor = UIColor.blue
                blockButton.setTitle(NSLocalizedString("unblock_user", comment: ""), for: UIControlState())
            } else{
                blockButton.tintColor = UIColor.red
                blockButton.setTitle(NSLocalizedString("block_contact", comment: ""), for: UIControlState())
            }
        }
    }
    
    func validateUI() {
        if let user = self.user {
            if user.relation == ContactRelation.FRIEND {
                contactsButton.tintColor = UIColor.red
                contactsButton.setTitle(NSLocalizedString("remove_contact", comment: ""), for: UIControlState())
            } else{
                contactsButton.tintColor = UIColor.blue
                contactsButton.setTitle(NSLocalizedString("add_contact", comment: ""), for: UIControlState())
            }
            
            if user.relation == ContactRelation.BLACKLIST {
                blockButton.tintColor = UIColor.blue
                blockButton.setTitle(NSLocalizedString("unblock_user", comment: ""), for: UIControlState())
            } else{
                blockButton.tintColor = UIColor.red
                blockButton.setTitle(NSLocalizedString("block_contact", comment: ""), for: UIControlState())
            }
        }
    }
    
    func set(userGroup: UserGroup) {
        self.userGroup = userGroup
        
        if self.view != nil {
            self.userImageView.image = nil
            userGroup.fetchPhoto({ (image, error) in
                self.userImageView.image = image
            })
            
            self.userName.text = userGroup.title
            self.statusText.text = nil
            
            if let creatorName = userGroup.creatorName {
                self.statusText.text = NSString(format: NSLocalizedString("invite_group_creator", comment:"") as NSString, creatorName) as String
            }
            
            contactsButtonHeight.constant = 0
            contactsButton.isHidden = true
            contactsButton.setNeedsDisplay()
            contactsButton.setNeedsLayout()
            contactsButton.layoutIfNeeded()
            
            blockButtonHeight.constant = 0
            blockButton.isHidden = true
            blockButton.setNeedsDisplay()
            blockButton.setNeedsLayout()
            blockButton.layoutIfNeeded()
            
            userGroup.fetchMembers { (members, error) in
                if let members = members {
                    self.userGroupMembers = members
                    self.groupTableView.reloadData()
                }
            }
        }
    }
    
    func set(question: Question){
        
        if self.view != nil {
            self.userImageView.image = nil
            self.statusText.text = nil
            self.userName.text = question.text
            
            let defaultIcon = UIImage(named: "LoginIcon")!
            Choice.fetchChoices(question: question, choiceId: nil, completion: {choices, error in
                if let choice = choices?.first {
                    choice.photo({image, error in
                        if let image = image {
                            self.userImageView.image = image
                        }
                        
                        User.fetchUsers(questionId: question.id, completion: {users, error in
                            if let creator = users?.filter({$0.id() == question.creatorId}).first {
                                self.statusText.text = NSString(format: NSLocalizedString("invite_group_creator", comment:"") as NSString, creator.username) as String
                            }
                            
                            if image == nil {
                                if let user = users?.filter({$0.user_id != GlobalQuestionData.user_id}).first, users?.count == 2 {
                                    user.fetchPhoto({userImage, error in
                                        if let userImage = userImage {
                                            self.userImageView.image = userImage
                                        } else {
                                            self.userImageView.image = defaultIcon
                                        }
                                    })
                                } else {
                                    self.userImageView.image = defaultIcon
                                }
                            }
                            
                            if users?.count == 2 {
                                self.userName.text = "Chat"
                            }
                        })
                    })
                } else {
                    User.fetchUsers(questionId: question.id, completion: {users, error in
                        if let creator = users?.filter({$0.id() == question.creatorId}).first {
                            self.statusText.text = NSString(format: NSLocalizedString("invite_group_creator", comment:"") as NSString, creator.username) as String
                        }
                        
                        if let user = users?.filter({$0.user_id != GlobalQuestionData.user_id}).first, users?.count == 2 {
                            user.fetchPhoto({userImage, error in
                                if let userImage = userImage {
                                    self.userImageView.image = userImage
                                } else {
                                    self.userImageView.image = defaultIcon
                                }
                            })
                        } else {
                            self.userImageView.image = defaultIcon
                        }
                        
                        if users?.count == 2 {
                            self.userName.text = "Chat"
                        }
                    })
                }
            })
            
            contactsButtonHeight.constant = 0
            contactsButton.isHidden = true
            contactsButton.setNeedsDisplay()
            contactsButton.setNeedsLayout()
            contactsButton.layoutIfNeeded()
            
            blockButtonHeight.constant = 0
            blockButton.isHidden = true
            blockButton.setNeedsDisplay()
            blockButton.setNeedsLayout()
            blockButton.layoutIfNeeded()
            
            User.fetchUsers(questionId: question.id, completion: {users, error in
                if let members = users {
                    self.userGroupMembers = members
                    self.groupTableView.reloadData()
                }
            })
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.userImageView.layer.masksToBounds = false
        self.userImageView.layer.cornerRadius = (self.userImageView.frame.size.width)/2
        self.userImageView.clipsToBounds = true
        
        // avoid separators at end:
        self.groupTableView.tableFooterView = UIView(frame: CGRect.zero)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.groupTableView.flashScrollIndicators()
    }
    
    func flipContact() {
        if let user = user {
            if user.relation == .FRIEND {
                User.removeFromContacts(userIds: [user.id()], completion: { (error) in
                    if error == nil {
                        if error == nil {
                            user.relation = .UNKNOWN
                            self.validateUI()
                        }
                    }
                })
            } else {
                User.addToContacts(userIds: [user.id()], relationType: .FRIEND) { (error) in
                    if error == nil {
                        user.relation = .FRIEND
                        self.validateUI()
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.userGroupMembers?.count ?? 0
    }
    
    //    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    //        return NSLocalizedString("Members", comment: "")
    //    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let user = self.userGroupMembers?[safe: indexPath.row] {
            let contactCell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as! ContactTableViewCell
            contactCell.configure(user: user)
            return contactCell
        }
        return UITableViewCell()
    }
    
    func blockUser(){
        if let user = user {
            if(user.relation != .BLACKLIST){
                User.addToContacts(userIds: [user.id()], relationType: .BLACKLIST) { (error) in
                    if error == nil {
                        user.relation = .BLACKLIST
                        self.validateUI()
                    }
                }
            } else{
                User.removeFromContacts(userIds: [user.id()], completion: { (error) in
                    if error == nil {
                        user.relation = .UNKNOWN
                        self.validateUI()
                    }
                })
            }
        }
        
    }
    
}
