//
//  ContactTableViewCell.swift
//  Judge it!
//
//  Created by Axel Katerbau on 29.09.16.
//  Copyright © 2016 Judge it. All rights reserved.
//

class ContactTableViewCell: UITableViewCell {
    
    @IBOutlet var photoImageView: UIImageView!
    @IBOutlet var usernameLabel: UILabel!
    @IBOutlet var statusTextLabel: UILabel!
    @IBOutlet var additionalInfoLabel: UILabel!
    
    fileprivate var userId: String = ""
    
    override func awakeFromNib() {
        photoImageView.layer.borderWidth = 1.0
        photoImageView.layer.masksToBounds = false
        photoImageView.layer.borderColor = UIColor.white.cgColor
        photoImageView.layer.cornerRadius = (photoImageView.frame.size.width)/2
        photoImageView.clipsToBounds = true
        
        self.prepareForReuse()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        self.usernameLabel.text = nil
        self.statusTextLabel.text = nil
        self.additionalInfoLabel.text = nil
    }
    
    func configure(user: User) {
        let isSameUser = (self.userId == user.id())
        self.userId = user.id()
        
        if !isSameUser {
            self.photoImageView.image = nil
        }
        
        user.fetchPhoto { (photo, error) in
            if user.id() == self.userId {
                self.photoImageView.image = photo
            }
        }
        
        usernameLabel.text = user.username
        statusTextLabel.text = user.statusText
        additionalInfoLabel.text = user.relation == .BLACKLIST ? NSLocalizedString("string_blocked", comment: "") : ""
    }
    
    func configure(phoneContact: PhoneContact){
        self.photoImageView.image = phoneContact.image
        
        usernameLabel.text = phoneContact.name
        statusTextLabel.text = phoneContact.phoneNumber
        additionalInfoLabel.text = ""
    }
    
}
