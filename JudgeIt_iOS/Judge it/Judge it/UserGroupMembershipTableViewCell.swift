//
//  UserGroupMembershipTableViewCell.swift
//  Judge it!
//
//  Created by Axel Katerbau on 29.09.16.
//  Copyright © 2016 Judge it. All rights reserved.
//

class UserGroupMembershipTableViewCell: UITableViewCell {
    
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
        
        if let creatorName = userGroup.creatorName {
            additionalInfoLabel.text = NSString(format: NSLocalizedString("invite_group_creator", comment:"") as NSString, creatorName) as String
        }
        
        memberCountLabel.text = ""
        
        userGroup.fetchMemberIds { (memberIds, error) in
            if let memberIds = memberIds {
                self.memberCountLabel.text = "(\(memberIds.count))"
            }
        }
    }
}
