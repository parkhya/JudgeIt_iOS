//
//  GroupEditController.swift
//  Judge it
//
//  Created by Carl Julius Gödecken on 30/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation
import UIKit
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
fileprivate func <= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l <= r
  default:
    return !(rhs < lhs)
  }
}


class GroupEditController : UIViewController, UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet var nameTextField: UITextField!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var groupIcon: UIImageView!
    
    @IBOutlet var confirmButton: UIBarButtonItem!
    
    @IBAction func saveGroup(_ sender: AnyObject) {
        saveGroup2()
    }
    
    lazy var imagePicker = UIImagePickerController()
    
    // parameters passed in prepareForSegue
    var contacts: [User]!
    var userGroup: UserGroup!
    var isNewGroup: Bool = false
    
    var newUsers = [User:Bool]()
    var newPhoto:UIImage? = nil
    
    var memberIds = [String]()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.localizeStrings()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        nameTextField.layer.borderColor = UIColor.red.cgColor
        nameTextField.layer.borderWidth = 1.0
        nameTextField.layer.cornerRadius = 5
        nameTextField.clipsToBounds = true
        
        let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(imageSelected))
        groupIcon.isUserInteractionEnabled = true
        groupIcon.addGestureRecognizer(tapGestureRecognizer)
        
        groupIcon.layer.borderWidth = 1.0
        groupIcon.layer.masksToBounds = false
        groupIcon.layer.borderColor = UIColor.white.cgColor
        groupIcon.layer.cornerRadius = groupIcon.frame.size.width/2
        groupIcon.clipsToBounds = true
        
        imagePicker.delegate = self
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        //self.navigationController?.navigationBar.topItem?.title = NSLocalizedString("cancel", comment: "")
    }
    
    func saveGroup2(){
        dismissKeyboard()
        
        let hasNoName = self.nameTextField.text == nil || self.nameTextField.text?.characters.count == 0
        let hasNoMembers = self.memberIds.count <= 1 // members apart from self
        
        if self.isNewGroup && !(hasNoName || hasNoMembers) {
            UserGroup.addGroup("", completion: {createdGroup, error in
                self.userGroup = createdGroup
                self.isNewGroup = false
                
                self.saveGroup2()
            })
        } else if !self.isNewGroup && !(hasNoName || hasNoMembers) {
            let group_dispatchGroup = DispatchGroup()
            
            if self.nameTextField.text != self.userGroup.title, let text = self.nameTextField.text?.trim() {
                group_dispatchGroup.enter()
                self.userGroup.setName(text, completion: {_  in
                    group_dispatchGroup.leave()
                })
            }
            
            if let photo = newPhoto{
                group_dispatchGroup.enter()
                self.userGroup.setPhoto(photo, completion: {error in
                    group_dispatchGroup.leave()
                })
            }
            
            let addedUsers = newUsers.flatMap({$1 ? $0.id() : nil})
            if addedUsers.count > 0 {
                group_dispatchGroup.enter()
                self.userGroup.addMembers(memberIds: addedUsers, completion: {_ in
                    group_dispatchGroup.leave()
                })
            }
            
            let removedUsers = newUsers.flatMap({!$1 ? $0.id() : nil})
            if removedUsers.count > 0 {
                group_dispatchGroup.enter()
                self.userGroup.removeMembers(memberIds: removedUsers, completion: {_ in
                    group_dispatchGroup.leave()
                })
            }
            
            group_dispatchGroup.notify(queue: DispatchQueue.main, execute: {
                NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
            })
            
            self.navigationController!.popViewController(animated: true)
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        dismissKeyboard()
        
        super.viewWillDisappear(animated)
    }
    
    
    @IBAction func nameTextEdited() {
        validateUI()
    }
    
    func reload() {
        self.validateUI()
        self.tableView.reloadData()
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.title = self.isNewGroup ? NSLocalizedString("group_create_title", comment: "") : NSLocalizedString("group_edit_title", comment: "")
        tableView.reloadData()
        
        if let group = self.userGroup {
            
            if(newPhoto == nil){
                group.fetchPhoto({ (photo, error) in
                    if let photo = photo {
                        self.groupIcon.image = photo
                        self.groupIcon.contentMode = .scaleAspectFill
                    }
                })
            }
            
            if(nameTextField.text?.length <= 0){
                nameTextField.text = group.title
            }
            
            if(memberIds.count <= 1){
                memberIds = group.memberList.map({$0.id()})
            }
            
            validateUI()
        }
        
        if(memberIds.count <= 1){
            self.userGroup.fetchMemberIds { (memberIds, error) in
                if let memberIds = memberIds {
                    self.memberIds = memberIds
                }
                if error != nil {
                    self.memberIds = ["users/\(GlobalQuestionData.user_id)"]
                }
                
                self.reload()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "GroupEdit")
        tracker?.send(GAIDictionaryBuilder.createScreenView().build()  as NSDictionary? as! [AnyHashable: Any])
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
        
        alert.popoverPresentationController?.sourceView = groupIcon
        
        present(alert, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerEditedImage] as? UIImage ?? info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            
            self.groupIcon.image = pickedImage
            self.groupIcon.contentMode = .scaleAspectFill
            
            self.newPhoto = pickedImage
            
            validateUI()
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func validateUI() {
        DispatchQueue.main.async(execute: {
            let hasNoName = self.nameTextField.text == nil || self.nameTextField.text?.length <= 0
            let hasNoMembers = self.memberIds.count <= 1 // members apart from self
            
            self.nameTextField.layer.borderWidth = hasNoName ? 1.0 : 0.0
            self.confirmButton.isEnabled = !(hasNoName || hasNoMembers)
        })
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let contactCell = tableView.dequeueReusableCell(withIdentifier: "ContactCell") as! ContactTableViewCell
        if let user = contacts[safe: indexPath.row] {
            contactCell.configure(user: user)
        }
        return contactCell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let userId = self.contacts[safe: indexPath.row]?.id() {
            if self.memberIds.contains(userId) {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        } else {
            cell.accessoryType = .none
        }
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if let contact = self.contacts[safe: indexPath.row] {
            return contact.id().rawId() != GlobalQuestionData.user_id
        }
        return true;
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let contact = self.contacts[safe: indexPath.row] {
            if self.memberIds.contains(contact.id()) {
                if contact.id().rawId() != GlobalQuestionData.user_id {
                    // Prevent de-selecting self:
                    
                    self.newUsers[contact] = false
                    self.memberIds.removeObject(contact.id())
                    self.reload()
                }
            } else {
                self.newUsers[contact] = true
                self.memberIds.append(contact.id())
                
                tableView.deselectRow(at: indexPath, animated: true)
                self.reload()
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
        
        validateUI()
    }
}
