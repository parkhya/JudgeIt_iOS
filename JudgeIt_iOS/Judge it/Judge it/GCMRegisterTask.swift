//
//  GCMRegisterTask.swift
//  Judge it
//
//  Created by Daniel Thevessen on 21/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation
import SwiftyJSON

struct GCMRegisterTask{
    
    class GCMTaskDelegate : TaskDelegate<Bool>{
    }
    
    static func gcmRegisterTask(_ token:String, delegate:GCMTaskDelegate){
        var request:[String:Any] = [
            "request_type": RequestType.GCM.rawValue,
            "version": Communicator.SERVER_VERSION,
            "debug": false,
            "instance_id": token,
            "platform": 4
        ]
        if(GlobalQuestionData.user_id != -1 && GlobalQuestionData.login_token != ""){
            request.updateValue(GlobalQuestionData.user_id, forKey: "user_id")
            request.updateValue(GlobalQuestionData.login_token, forKey: "login_token")
        }
        
        Communicator.instance.communicateWithServer(request, callback: gcmCallback, delegate: delegate)
    }
    
    static func gcmCallback(_ response:JSON, delegate:TaskDelegate<Bool>){
        var result = false
        if let response_code = response["response_code"].int{
            if response_code != ResponseCode.FAIL.rawValue{
                result = true
            }
        }
        delegate.onPostExecute(result)
    }
    
}
