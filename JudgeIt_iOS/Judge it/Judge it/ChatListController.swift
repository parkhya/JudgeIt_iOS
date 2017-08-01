//
//  ChatListController.swift
//  Judge it!
//
//  Created by Daniel Theveßen on 30.04.17.
//  Copyright © 2017 Judge it. All rights reserved.
//

import Foundation

class ChatListController : PrivateVotingListController {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        showChat = true
    }
    
}
