//
//  TaskCollection.swift
//  Judge it
//
//  Created by Daniel Thevessen on 17/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class TaskDelegate<T>{
    func onPostExecute(_ result: T) -> Void{
        preconditionFailure("Method has to be overriden!")
    }
    
    func onFail(){
        // do nothing, may be implemented in subclasses
    }
}

struct TaskCollection{
    
    static func initRequest(_ request_type:RequestType) -> [String:Any]{
        return initRequest(request_type, debug: false)
    }
    
    static func initRequest(_ request_type:RequestType, debug:Bool) -> [String:Any]{
        let request:[String:Any] = [
            "user_id": GlobalQuestionData.user_id,
            "login_token": GlobalQuestionData.login_token,
            "request_type": request_type.rawValue,
            "version": Communicator.SERVER_VERSION,
            "debug": debug
        ]
        return request
    }
    
}
