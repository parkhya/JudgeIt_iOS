//
//  UserGroupTableViewCell.swift
//  Judge it!
//
//  Created by Axel Katerbau on 29.09.16.
//  Copyright © 2016 Judge it. All rights reserved.
//

class UserGroupTableViewCell: UITableViewCell {

    @IBOutlet var photoImageView: UIImageView!
    @IBOutlet var groupnameLabel: UILabel!
    @IBOutlet var additionalInfoLabel: UILabel!
    @IBOutlet var memberCountLabel: UILabel!
    
    fileprivate var userGroupId: String = ""
    
    override func awakeFromNib() {
        photoImageView.layer.borderWidth = 1.0
        photoImageView.layer.masksToBounds = false
        photoImageView.layer.borderColor = UIColor.white.cgColor
        photoImageView.layer.cornerRadius = (photoImageView.frame.size.width)/2
        photoImageView.clipsToBounds = true
    }

    func configure(userGroup: UserGroup) {
        self.userGroupId = userGroup.id()
        
        self.photoImageView.image = nil
        
        userGroup.fetchPhoto { (photo, error) in
            if userGroup.id() == self.userGroupId {
                self.photoImageView.image = photo
            }
        }
        
        groupnameLabel.text = userGroup.title.length > 0 ? userGroup.title : " "
        
        additionalInfoLabel.text = ""
        memberCountLabel.text = ""
        
        userGroup.fetchMembers { (users, error) in
            if let users = users {
                let firstUsers = users[0..<min(users.count, 10)]
                let firstUsersNames = firstUsers.reduce([String]()) { (previousNames, user) -> [String] in
                    var names = previousNames
                    names.append(user.username)
                    return names
                }
                let firstUserText = firstUsersNames.joined(separator: ", ")
                
                self.additionalInfoLabel.text = firstUserText
                self.memberCountLabel.text = "(\(users.count))"
            }
        }
    }
    
}
