//
//  ClientServerCommunicator.swift
//  Judge it
//
//  Created by Daniel Thevessen on 10/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import SwiftyJSON
import Alamofire
import AlamofireImage

let UnauthorizedRequestDidHappenNotification = "UnauthorizedRequestDidHappenNotification"

extension SessionManager {
    
    //    func invalidateCache(URLString: URLStringConvertible,
    //                       parameters: [String: AnyObject]? = nil,
    //                       headers: [String: String]? = nil) {
    //
    //        let mutableURLRequest = NSMutableURLRequest(URL: NSURL(string: URLString.URLString)!)
    //        mutableURLRequest.HTTPMethod = Alamofire.Method.GET.rawValue
    //        mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    //
    //        if let headers = headers {
    //            for (headerField, headerValue) in headers {
    //                mutableURLRequest.setValue(headerValue, forHTTPHeaderField: headerField)
    //            }
    //        }
    //
    //        let encodedURLRequestForCache = ParameterEncoding.URLEncodedInURL.encode(mutableURLRequest, parameters: parameters).0
    //
    //        if (self.session.configuration.URLCache?.cachedResponseForRequest(encodedURLRequestForCache)) != nil {
    //            self.session.configuration.URLCache?.removeCachedResponseForRequest(encodedURLRequestForCache)
    //
    //            let emptyResponse = NSCachedURLResponse()
    //            self.session.configuration.URLCache?.storeCachedResponse(emptyResponse, forRequest: encodedURLRequestForCache)
    //            let check = self.session.configuration.URLCache?.cachedResponseForRequest(encodedURLRequestForCache)
    //        }
    //    }
    
    func getJSONObject(_ URLString: URLConvertible,
                       parameters: [String: Any]? = nil,
                       headers: [String: String]? = nil,
                       alsoCached: Bool = true,
                       callbackOnce:Bool = false,
                       loadIfModifiedSinceDate: NSDate? = nil,
                       queue: DispatchQueue? = nil,
                       completion: @escaping (Any?, NSError?) -> Void) {
        
        var requestHeaders = ["Accept": "application/json"]
        if let headers = headers {
            for (headerField, headerValue) in headers {
                requestHeaders.updateValue(headerValue, forKey: headerField)
            }
        }
        
        let urlRequestForCache = try! URLRequest(url: URLString.asURL(), method: .get, headers: requestHeaders)
        let encodedURLRequestForCache = try! URLEncoding.default.encode(urlRequestForCache, with: parameters)
        
        var etag: String? = nil
        var shouldCheckServer = true
        let cachedURLResponse = self.session.configuration.urlCache?.cachedResponse(for: encodedURLRequestForCache)
        var cachedJSON: Any? = nil
        var hasCachedJSONAlreadyBeenDelivered: Bool = false
        
        if cachedURLResponse != nil {
            if loadIfModifiedSinceDate != nil {
                if let userInfo = cachedURLResponse!.userInfo, let dateString = userInfo["Cached-At"] as? String, let lastModifiedDate = Date.RFC1123DateFormatter.date(from: dateString) {
                    shouldCheckServer = lastModifiedDate.compare(loadIfModifiedSinceDate! as Date) == .orderedAscending
                }
            }
            
            if let httpURLResponse = cachedURLResponse!.response as? HTTPURLResponse {
                if let cachedEtag = httpURLResponse.allHeaderFields["ETag"] as? String {
                    etag = cachedEtag
                }
                
                if loadIfModifiedSinceDate != nil {
                    if let lastModfiedString = httpURLResponse.allHeaderFields["Last-Modified"] as? String, let lastModifiedDate = Date.RFC1123DateFormatter.date(from: lastModfiedString) {
                        shouldCheckServer = lastModifiedDate.compare(loadIfModifiedSinceDate! as Date) == .orderedAscending
                    }
                }
            }
            
            do {
                cachedJSON = try JSONSerialization.jsonObject(with: cachedURLResponse!.data, options: .allowFragments)
            } catch {
                self.session.configuration.urlCache?.removeCachedResponse(for: encodedURLRequestForCache)
                etag = nil
            }
            
            if alsoCached && cachedJSON != nil {
                completion(cachedJSON!, nil)
                hasCachedJSONAlreadyBeenDelivered = true
            }
        }
        
        if !shouldCheckServer && hasCachedJSONAlreadyBeenDelivered {
            return
        }
        
        if etag != nil {
            requestHeaders.updateValue(etag!, forKey: "If-None-Match")
        }
        
        var urlRequest = try! URLRequest(url: URLString.asURL(), method: .get, headers: requestHeaders)
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        let encodedURLRequest = try! URLEncoding.default.encode(urlRequest, with: parameters)
        
        request(encodedURLRequest).responseJSON(queue: queue) { (response) in
            if let error = response.result.error {
                if let urlResponse = response.response {
                    switch(urlResponse.statusCode) {
                    case 304:
                        // refresh Cached-At for entry:
                        if cachedURLResponse != nil && response.response!.allHeaderFields["Last-Modified"] == nil {
                            let userInfo = ["Cached-At" : Date.RFC1123DateFormatter.string(from: Date())]
                            let cachedResponse = CachedURLResponse(response: cachedURLResponse!.response, data: cachedURLResponse!.data, userInfo: userInfo, storagePolicy: .allowed)
                            self.session.configuration.urlCache?.storeCachedResponse(cachedResponse, for: encodedURLRequestForCache)
                        }
                        
                        if !hasCachedJSONAlreadyBeenDelivered {
                            completion(cachedJSON, nil)
                        }
                    case 401, 403:
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: UnauthorizedRequestDidHappenNotification), object: nil)
                    default:
                        if !(callbackOnce && hasCachedJSONAlreadyBeenDelivered) {
                            completion(nil, error as NSError?)
                        }
                    }
                }
            } else {
                if let JSON = response.result.value, !(callbackOnce && hasCachedJSONAlreadyBeenDelivered){
                    completion(JSON, nil)
                    if let urlResponse = response.response, let data = response.data {
                        var userInfo: [AnyHashable: Any]? = nil
                        if urlResponse.allHeaderFields["Last-Modified"] == nil {
                            userInfo = ["Cached-At" : Date.RFC1123DateFormatter.string(from: Date())]
                        }
                        
                        let cachedResponse = CachedURLResponse(response: urlResponse, data: data, userInfo: userInfo, storagePolicy: .allowed)
                        
                        self.session.configuration.urlCache?.storeCachedResponse(cachedResponse, for: encodedURLRequestForCache)
                    }
                }
            }
        }
    }
    
}

class Communicator : NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    
    static let serverTrustPolicies: [String: ServerTrustPolicy] = [
        "judgeit-test.eu-central-1.elasticbeanstalk.com": .disableEvaluation,
        "api.judge-it.net": .disableEvaluation
    ]
    
    static let manager: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = Alamofire.SessionManager.defaultHTTPHeaders
        configuration.urlCache = URLCache(memoryCapacity: 1024 * 1024 * 4, diskCapacity: 1024 * 1024 * 25, diskPath: "WMCURLCache")
        return Alamofire.SessionManager(configuration: configuration,
                                        serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies))
    }()
    
    static let uncachedManager: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = Alamofire.SessionManager.defaultHTTPHeaders
        configuration.urlCache = nil
        configuration.requestCachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        return Alamofire.SessionManager(configuration: configuration,
                                        serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies))
    }()
    
    static let imageDownloader: ImageDownloader = {
        let configuration = ImageDownloader.defaultURLSessionConfiguration()
        //        configuration.URLCache = NSURLCache(memoryCapacity: 1024 * 1024 * 6, diskCapacity: 1024 * 1024 * 50, diskPath: "WMCMediaURLCache")
        let downloadSessionManager = Alamofire.SessionManager(configuration: configuration,
                                                              serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies))
        
        return ImageDownloader(sessionManager: downloadSessionManager, downloadPrioritization: .fifo, maximumActiveDownloads: 4, imageCache: AutoPurgingImageCache())
    }()
    
    enum CommunicationError : Error {
        case emptyResult
        case serverResponse(responseCode: ResponseCode)
    }
    
    static let instance = Communicator()
    
    
    
    #if RELEASE
    let SERVER_URL = "https://api.judge-it.net"
    #else
//        let SERVER_URL = "https://judgeit-test.eu-central-1.elasticbeanstalk.com"
    let SERVER_URL = "https://api.judge-it.net"
    //    let SERVER_URL:String! = "http://localhost:3000"
    // let SERVER_URL:String! = "http://ratz:3000"
    #endif
    
    var session:Foundation.URLSession?
    
    static let SERVER_VERSION = 31
    
    fileprivate override init() {
        super.init()
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 50
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = Foundation.URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }
    
    static let jsonWritingOptions = JSONSerialization.WritingOptions()
    
    func communicateWithServer(_ params: [String : Any], completion: ((JSON?, NSError?) -> Void)?) {
        
        let requestObj = NSMutableURLRequest(url: URL(string: "\(self.SERVER_URL)/api")!)
        requestObj.httpMethod = "POST"
        
        do {
            requestObj.httpBody = try JSONSerialization.data(withJSONObject: params, options: Communicator.jsonWritingOptions)
        } catch let error as NSError {
            DispatchQueue.main.async(execute: {
                completion?(nil, error)
                print("\(error.localizedDescription)")
            })
            return
        }
        
        requestObj.addValue("application/json", forHTTPHeaderField: "Content-Type")
        requestObj.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let dataTask = self.session!.dataTask(with: requestObj as URLRequest, completionHandler: { data, response, error in
            let json: JSON? = (data != nil) ? JSON(data: data!) : nil
            
            DispatchQueue.main.async(execute: {
                // Handle response
                if let error = error {
                    print("communicateWithServer: " + error.localizedDescription)
                    completion?(nil, error as NSError?)
                } else {
                    if let json = json {
                        if let rawResponseCode = json["response_code"].int, ResponseCode.errorResponseCodes().contains(ResponseCode(rawValue: rawResponseCode)!) {
                            print("Communication error: uid \(GlobalQuestionData.user_id) token \(GlobalQuestionData.login_token) \(rawResponseCode)")
                            let error = NSError.init(domain: "CommunicationError", code: rawResponseCode, userInfo: nil)
                            completion?(nil, error)
                        } else {
                            completion?(json, nil)
                        }
                    } else {
                        let error = NSError.init(domain: "CommunicationError", code: 0, userInfo: nil)
                        completion?(nil, error)
                    }
                }
            });
        })
        
        //https://openradar.appspot.com/23956486
        dataTask.priority = 0.75//NSURLSessionTaskPriorityHigh
        dataTask.resume()
    }
    
    
    // Legacy call; should go away ASAP
    //@available(*, deprecated=1.0.4)
    func communicateWithServer<T>(_ params:[String : Any], callback: @escaping (JSON, TaskDelegate<T>) -> Void, delegate: TaskDelegate<T>){
        
        self.communicateWithServer(params) { (json, error) in
            if (error==nil && json != nil) {
                callback(json!, delegate)
            } else {
                delegate.onFail()
            }
        }
    }
    
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler:@escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust:
            challenge.protectionSpace.serverTrust!))
    }
    
    //    func reAuthenticate(callback: (Bool)->()){
    //        let prefs = NSUserDefaults.standardUserDefaults()
    //        if let pref_mail = prefs.objectForKey("pref_user") as? String{
    //            if let pref_pass = prefs.secretObjectForKey("pref_pass") as? String{
    //                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0) , {
    //                    LoginTask.loginTask(pref_mail, password: pref_pass, externalAccount: nil, externalUser: nil, delegate: MyLoginDelegate(parent: self, newRegistration: false))
    //                })
    //            }
    //        }
    //
    //        if let fbToken = FBSDKAccessToken.currentAccessToken() {
    //            doFacebookLogin(fbToken)
    //        } else if let googleToken = GIDSignIn.sharedInstance().currentUser {
    //            doGoogleLogin(googleToken)
    //        } else{
    //            GIDSignIn.sharedInstance().signInSilently()
    //        }
    //    }
    //
    //    class MyLoginDelegate : LoginTask.LoginTaskDelegate{
    //
    //        override func onPostExecute(response: JSON) -> Void {
    //            print("onPost \(response)")
    //
    //                if let response_code = response["response_code"].int{
    //                    if(response_code == ResponseCode.OK.rawValue){
    //                        let user_id = response["user_id"].int
    //                        let login_token = response["login_token"].string
    //                        if(user_id != nil && login_token != nil){
    //                            GlobalQuestionData.user_id = user_id!
    //                            GlobalQuestionData.login_token = login_token!
    //                            GlobalQuestionData.afterLogout = false
    //                        }
    //                    }
    //                }
    //        }
    //
    //    }
    
    
}
