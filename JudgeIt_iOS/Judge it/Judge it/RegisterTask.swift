//
//  RegisterTask.swift
//  Judge it
//
//  Created by Daniel Thevessen on 16/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation
import SwiftyJSON

class RegisterTask{
    
//    class RegisterTaskDelegate: TaskDelegate<JSON>{
//    }
    
    static func registerTask(_ email: String, password: String, completion: ((JSON?, NSError?) -> Void)?){
        var request = TaskCollection.initRequest(RequestType.CLAIM_ACCOUNT)
        let data:[String:Any] = [
            "email": email,
            "pass": password
        ]
        request.updateValue(data, forKey: "data")
        
        Communicator.instance.communicateWithServer(request, completion: completion)
    }
    
//    static func registerCallback(response:JSON, delegate:TaskDelegate<JSON>){
//        delegate.onPostExecute(response)
//    }
    
}
