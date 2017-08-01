//
//  Comment.swift
//  Judge it
//
//  Created by Daniel Thevessen on 10/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import UIKit
import Alamofire

class Comment {
    
    let id: String
    let questionId: String
    let userId: String
    let created: Date
    let text: String?
    let photoId: String?
    let leave:Bool
    let stop:Bool
    let addedChoice:Int?
    let invitedMember: Int?
    let isSticker:Bool
    let isCreationNotice:Bool
    
    init(dictionary: Dictionary<String, Any>) {
        self.id = (dictionary["id"] as! String)
        self.questionId = (dictionary["contained-in-id"] as! String)
        self.userId = (dictionary["user-id"] as! String)
        self.created = Date(timeIntervalSince1970: Double(dictionary["created"] as! Int!))
        self.text = dictionary["text"] as? String
        self.photoId = dictionary["photo-id"] as? String
        self.leave = (dictionary["leave"] as? Int ?? 0) == 1
        self.stop = (dictionary["stop"] as? Int ?? 0) == 1
        self.addedChoice = dictionary["choices"] as? Int
        self.invitedMember = (dictionary["join"] as? [Int])?.first
        self.isSticker = (dictionary["stickers"] as? Int ?? 0) == 1
        self.isCreationNotice = (dictionary["create-notice"] as? Int ?? 0) == 1
    }
  
    static func sendComment(_ questionId: String, text: String?, photo: UIImage?, leave:Int = 0, stop:Int = 0, choices:Int? = nil, created:Int? = 0, join:[Int]? = nil, sticker:Int? = 0, completion: @escaping (Comment?, NSError?) -> Void) -> Comment {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async { 
            var parameters = [String: Any]()
            
            if let text = text, text.characters.count > 0 {
                parameters["text"] = text
            }
            
            if let photo = photo {
                let preparedphoto = photo.resizeToWidth(500)
                let imageData = UIImageJPEGRepresentation(preparedphoto, 0.95)
                let base64String = imageData?.base64EncodedString(options: .lineLength64Characters)
                
                parameters["photo-base64"] = base64String
            }
            
            // Metadata to signal user left the voting
            parameters["leave"] = leave
            // Metadata to signal voting is closed
            parameters["stop"] = stop
            // Metadata to signal voting was created
            parameters["created"] = created
            // Metadata to signal new choice was added
            if(choices != nil){
                parameters["choices"] = choices
            }
            // Metadata to signal new member was invited
            if(join != nil){
                parameters["join"] = join
            }
            // Metadata to indicate attached picture is a sticker
            parameters["stickers"] = sticker
            
            DispatchQueue.main.async(execute: { 
                if parameters.count > 0 {
                    parameters["user-id"] = GlobalQuestionData.user_id
                    parameters["token"] = GlobalQuestionData.login_token
                    
                    let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + questionId + "/comments"
                    Communicator.manager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json"]).responseJSON(completionHandler: { (response) in
                        if let error = response.result.error {
                            completion(nil, error as NSError?)
                        } else {
                            let commentDictionary: Dictionary<String, AnyObject> = response.result.value as! Dictionary<String, AnyObject>
                            let createdDict = commentDictionary["created"] as! Dictionary<String, AnyObject>
                            let commentsArray = createdDict["comments"] as! Array<AnyObject>
                            let commentDict = commentsArray.first as! Dictionary<String, AnyObject>
                            let comment = Comment(dictionary: commentDict)
                            completion(comment, nil)
                        }
                    })
                } else {
                    completion(nil, nil);
                }
            })
        }
        
        var tempParameters = [String: Any]()
        tempParameters["text"] = text
        tempParameters["id"] = "comments/\(-2)"
        tempParameters["created"] = Int(Date().timeIntervalSince1970)
        tempParameters["contained-in-id"] = questionId
        tempParameters["user-id"] = "users/\(GlobalQuestionData.user_id)"
        tempParameters["stickers"] = sticker
        if photo != nil {
            tempParameters["photo-id"] = "tempPhotoId"
        }
        return Comment(dictionary: tempParameters)
    }

//    static func commentIds(questionId: String, completion: ([String]?, NSError?) -> Void) {
//        var parameters = [String: AnyObject]()
//        parameters["fields"] = "id"
//        parameters["question-id"] = questionId
//        parameters["user-id"] = GlobalQuestionData.user_id
//        parameters["token"] = GlobalQuestionData.login_token
//        
//        Communicator.manager.request(.GET, Communicator.instance.SERVER_URL + "/api/v2/" + questionId + "/comments", parameters: parameters, encoding: ParameterEncoding.URLEncodedInURL, headers: ["Accept": "application/json"]).responseJSON(completionHandler: { (response) in
//            if let error = response.result.error {
//                completion(nil, error)
//            } else {
//                var result = [String]()
//                let commentsArray = response.result.value as! Array<Dictionary<String, AnyObject>>
//                for commentDict in commentsArray {
//                    let id = commentDict["id"] as! String
//                    result.append(id)
//                }
//                completion(result, nil)
//            }
//        })
//    }
    
    static func fetchFollowedUpComments(_ question: Question, alsoCached: Bool = true, completion: @escaping ([Comment]?, NSError?) -> Void) {
        // TODO: more than one followup in chain
        if let followupToId = question.followupToId, followupToId.length > 0 {
            fetchComments(questionId: followupToId, commentId: nil, completion: completion)
        } else {
            completion([], nil)
        }
    }
    
    static func fetchComments(questionId: String, commentId: String?, callbackOnce:Bool = false, alsoCached: Bool = true, completion: @escaping ([Comment]?, NSError?) -> Void) {
        var parameters = [String: Any]()
        
        parameters["comment-id"] = commentId
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        
        var urlString = Communicator.instance.SERVER_URL + "/api/v2/" + questionId
        if let commentId = commentId {
            urlString += ("/" + commentId)
        } else {
            urlString += "/comments"
        }
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters, alsoCached: alsoCached, callbackOnce: callbackOnce) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                if let commentsArray = JSON as? Array<Dictionary<String, AnyObject>> {
                    var result = [Comment]()
                    for commentDict in commentsArray {
                        let comment = Comment(dictionary: commentDict)
                        result.append(comment)
                    }
                    result = result.filter({($0.text?.length ?? 0) > 0 || $0.photoId != nil || $0.leave || $0.stop || $0.addedChoice != nil || $0.invitedMember != nil || $0.isCreationNotice})
                    
                    completion(result, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    func photo(_ completion: @escaping (UIImage?, Error?) -> Void) {
        if let photoId = self.photoId, let url = URL(string: Communicator.instance.SERVER_URL + "/cdn/" + photoId + "?uid=\(GlobalQuestionData.user_id)&ltk=\(GlobalQuestionData.login_token)") {
            let urlRequest = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            Communicator.imageDownloader.download(urlRequest) { (response) in
                if let image = response.result.value {
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

func == (left: Comment, right: Comment) -> Bool {
    return left.id == right.id
}

func != (left:Comment, right:Comment) -> Bool {
    return !(left == right)
}

