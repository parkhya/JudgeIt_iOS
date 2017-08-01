//
//  LoginTask.swift
//  Judge it
//
//  Created by Daniel Thevessen on 14/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation
import SwiftyJSON

class LoginTask {
    
    internal enum ExternalAccount:Int{
        case facebook = 0, google, microsoft
    }
    
    internal class LoginTaskDelegate : TaskDelegate<JSON>{
    }
    
    static func castNSNull(_ sender: AnyObject?) -> AnyObject{
        return sender != nil ? sender! : NSNull()
    }
    
    static func loginTask(_ email:String?, password:String, externalAccount:ExternalAccount?, externalUser:String?, completion: ((JSON?, NSError?) -> Void)?) {
        
        var loginParams:[String:Any] = [
            "request_type": RequestType.LOGIN.rawValue as NSNumber,
            "version": Communicator.SERVER_VERSION,
            "debug": false
        ]
        var data:[String:Any] = [
            "pass": password
        ]
        data.updateValue(email ?? NSNull(), forKey: "email")
        data.updateValue(externalUser ?? NSNull(), forKey: "external_userid")
        data.updateValue(externalAccount?.rawValue ?? NSNull(), forKey: "external_account")
        loginParams.updateValue(data, forKey: "data")
        
        Communicator.instance.communicateWithServer(loginParams, completion: completion)
    }    
    
}
