//
//  VotingListController.swift
//  Judge it!
//
//  Created by Daniel Theveßen on 29/01/2017.
//  Copyright © 2017 Judge it. All rights reserved.
//

import Foundation

class VotingListViewController : UITableViewController {
    
    func reloadQuestions(forced: Bool = false, userBlocked:String? = nil) -> Void {
        preconditionFailure("This method must be overridden")
    }
    
    func selectQuestion(_ questionId: String, tab: VotingViewController.TabTag) {
        preconditionFailure("This method must be overridden")
    }
    
    func chatIconPress(indexPath:IndexPath) {
        preconditionFailure("This method must be overridden")
    }
    
    func voteIconPress(indexPath:IndexPath){
        preconditionFailure("This method must be overridden")
    }
}
