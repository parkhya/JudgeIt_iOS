//
//  UpdateType.swift
//  Judge it
//
//  Created by Daniel Thevessen on 11/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation

public enum UpdateType : Int{
    case NEW_QUESTION = 0, NEW_VOTES, NEW_COMMENT, NEW_CHOICE, NEW_QUESTION_SELF, INVITE_GROUP
    
    func order()->Int{
        switch(self){
        case .NEW_QUESTION:
            return 5
        case .NEW_CHOICE:
            return 4
        case .NEW_COMMENT:
            return 3
        case .NEW_VOTES:
            return 2
        case .INVITE_GROUP:
            return 1
        case .NEW_QUESTION_SELF:
            return 0
        }
    }
}

func <= (left: UpdateType, right: UpdateType) -> Bool {
    return left.order() <= right.order()
}

public func == (left: UpdateType, right: UpdateType) -> Bool {
    return left.order() == right.order()
}

func != (left: UpdateType, right: UpdateType) -> Bool {
    return left.order() != right.order()
}

func >= (left: UpdateType, right: UpdateType) -> Bool {
    return left.order() >= right.order()
}

func > (left: UpdateType, right: UpdateType) -> Bool {
    return left.order() > right.order()
}

func < (left: UpdateType, right: UpdateType) -> Bool {
    return left.order() < right.order()
}
