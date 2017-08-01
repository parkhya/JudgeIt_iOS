//
//  UserListItem.swift
//  Judge it
//
//  Created by Daniel Thevessen on 13/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import UIKit

@objc protocol UserListItem {
    
    var title: String {get}
    var description: String {get}
    var picture: UIImage? {get set}
    var picturePath: String? {get set}
    
    func id() -> String
    
    func isOrderedBefore(_ other: UserListItem) -> Bool

}
