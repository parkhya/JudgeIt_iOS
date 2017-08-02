//
//  Choice.swift
//  Judge it
//
//  Created by Daniel Thevessen on 10/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import UIKit
import Alamofire
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}


class Choice : Hashable {
    
    let id: String
    var text: String // currently modified by question edit controller, should be changed to let
    let created: Date
    let ratingsCount: Int
    
    let photoId: String?
    
    // currently modified by question edit controller, should be removed:
    var picture:UIImage?
    var pictureString:String?
    
    var date_from:Date?
    var date_to:Date?
    
    var hashValue: Int { return id.rawId()! }
    
    func url() -> URL? {
        if let url = URL(string: self.text) {
            return UIApplication.shared.canOpenURL(url) ? url : nil
        } else {
            return nil
        }
    }
    
    // currently used by question edit controller, should be removed:
    init(choiceText:String) {
        self.id = "choices/-1"
        self.text = choiceText
        self.created = Date(timeIntervalSince1970: Double(-1))
        self.ratingsCount = 0
        self.photoId = nil
    }
    
    func isValid() -> Bool {
        let result = self.picture != nil || self.photoId?.length > 0 || self.text.trim().length > 0
        return result
    }
    
    func isNew() -> Bool {
        return id == "choices/-1"
    }
    
    init(dictionary: Dictionary<String, AnyObject>) {
        
        self.id = dictionary["id"] as! String
        self.text = dictionary["text"] as? String ?? ""
        self.photoId = dictionary["photo-id"] as? String
        self.created = Date(timeIntervalSince1970: Double(dictionary["created"] as! Int!))
        self.ratingsCount = dictionary["ratings-count"] as? Int ?? 0
    }
    
    static func fetchChoices(question: Question, choiceId: String?, alsoCached: Bool = true, callbackOnce: Bool = false, queue: DispatchQueue? = nil, completion: @escaping ([Choice]?, NSError?) -> Void) {
        var parameters = [String: Any]()
        
        parameters["choice-id"] = choiceId
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        
        var urlString = Communicator.instance.SERVER_URL + "/api/v2/" + question.id
        if let choiceId = choiceId {
            urlString += ("/" + choiceId)
        } else {
            urlString += "/choices"
        }
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters, alsoCached: alsoCached, callbackOnce: callbackOnce, queue: queue) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                if let choicesArray = JSON as? Array<Dictionary<String, AnyObject>> {
                    print("choicesArray...........\(choicesArray)")
                    var result = [Choice]()
                    for choicesDict in choicesArray {
                        let choice = Choice(dictionary: choicesDict)
                        result.append(choice)
                    }
                    
                    completion(result, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    static func dictionariesFromChoices(_ choices: [Choice]) -> [[String: Any]] {
        var result = [[String: Any]]()
        for choice in choices {
            var choiceDictionary = [String: Any]();
            choiceDictionary["text"] = choice.text
            if choice.pictureString?.characters.count > 0 {
                choiceDictionary["photo-base64"] = choice.pictureString
            }
            result.append(choiceDictionary)
        }
        
        return result
    }
    
    static func addChoices(questionId: String, choicesDictionaries: [[String: Any]], completion: @escaping ([Choice]?, NSError?) -> Void) {
        
        let parameters:[String : Any] = [
            "user-id": GlobalQuestionData.user_id,
            "token": GlobalQuestionData.login_token,
            "choices": choicesDictionaries]
        
        Communicator.manager.request(Communicator.instance.SERVER_URL + "/api/v2/" + questionId + "/choices",
                                     method: .post,
                                     parameters: parameters,
                                     encoding: JSONEncoding.default,
                                     headers: ["Accept": "application/json"])
            .responseJSON(completionHandler: { (response) in
                if let error = response.result.error {
                    completion(nil, error as NSError?)
                } else {
                    let choicesArray = (response.result.value! as AnyObject).value(forKeyPath: "created.choices") as! Array<Dictionary<String, AnyObject>>
                    let choices = choicesArray.map({Choice(dictionary: $0)})
                    completion(choices, nil)
                }
            })
    }
    
    func photo(_ completion: @escaping (UIImage?, Error?) -> Void) {
        if self.picture != nil {
            completion(self.picture!, nil)
            return
        }
        
        if let photoId = self.photoId, let url = URL(string: Communicator.instance.SERVER_URL + "/cdn/" + photoId + "?uid=\(GlobalQuestionData.user_id)&ltk=\(GlobalQuestionData.login_token)") {
            let urlRequest = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            Communicator.imageDownloader.download(urlRequest) { (response) in
                if let image = response.result.value {
                    self.picture = image
                    completion(image, nil)
                } else {
                    completion(nil, response.result.error)
                }
            }
        } else {
            completion(nil, nil)
        }
    }
    
}

func == (left: Choice, right: Choice) -> Bool {
    return left.id == right.id
}

func != (left:Choice, right:Choice) -> Bool {
    return !(left == right)
}
