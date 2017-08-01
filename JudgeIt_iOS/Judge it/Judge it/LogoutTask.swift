//
//  LogoutTask.swift
//  Judge it
//
//  Created by Daniel Thevessen on 16/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation
import SwiftyJSON

class LogoutTask{
    
    class LogoutTaskDelegate : TaskDelegate<Bool>{
    }
    
    static func logoutTask(_ delegate:LogoutTaskDelegate){
        let request = TaskCollection.initRequest(RequestType.LOGOUT)
        Communicator.instance.communicateWithServer(request, callback: logoutCallback, delegate: delegate)
    }
    
    static func logoutCallback(_ response:JSON, delegate:TaskDelegate<Bool>){
        var result = false
        if let response_code = response["response_code"].int{
            if response_code == ResponseCode.OK.rawValue{
                result = true
            }
        }
        delegate.onPostExecute(result)
    }
    
}
