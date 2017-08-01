//
//  PhoneContact.swift
//  Judge it!
//
//  Created by Daniel Thevessen on 10/01/2017.
//  Copyright © 2017 Judge it. All rights reserved.
//

import Foundation

class PhoneContact : Hashable{
    
    var hashValue: Int

    static func ==(lhs: PhoneContact, rhs: PhoneContact) -> Bool {
        return lhs.phoneNumber == rhs.phoneNumber
    }

    
    let name:String
    let phoneNumber:String
    let image:UIImage?
    
    var inviteSent = false
    
    init(name:String, phoneNumber:String, image:UIImage?){
        self.name = name
        self.phoneNumber = phoneNumber
        self.image = image
        
        self.hashValue = phoneNumber.hashValue
    }
    
}
