//
//  RESTModel.swift
//  Judge it!
//
//  Created by Axel Katerbau on 12.09.16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import UIKit
import Alamofire

class RESTModel {
    static func bla() {
        
        Alamofire.request(.GET, "http://localhost:3000/api/v2/questions/1195", parameters: ["token" :"681cec4d028a61bbfa0b3061394621105763f92d6e9fb9282a510590c30a783d7657271ebd863e2897098595f4308f9662c6a1fa66a38ef491d0b7705cd3ea4e", "user-id" : 442,
            "fields" : "id,modified"], encoding: ParameterEncoding.URL, headers: ["If-Modified-Since" : "Fri, 09 Sep 2016 07:35:09 GMT"]).responseJSON { (response) in
//            debugPrint(response)
            
                if let request = response.request {
                    if response.response?.statusCode == 304 {
                        let cachedResponse = NSURLCache.sharedURLCache().cachedResponseForRequest(request)
                        print(cachedResponse)
                    }
                }
            print(response.result.value?.description)
//            if let json = response.result.value {
//                print("JSON: \(json)")
//            }
        }
     }
    
}
