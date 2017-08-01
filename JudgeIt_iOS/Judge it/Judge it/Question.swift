//
//  Question.swift
//  Judge it
//
//  Created by Daniel Thevessen on 10/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import UIKit
import SwiftyJSON
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


open class Question : NSObject {
    
    let id: String
    let creatorId: String
    var accessType: Int
    let text: String
    let created: Date
    let lastModification: Date
    let isUnseen: Bool
    let isMuted: Bool
    let unseenCountComments: Int
    let unseenCountRatings: Int
    let unseenCountChoices: Int
    let followupToId: String?
    let isClosed:Bool
    
    let isPublic:Bool
    var isRandomVoting = false
    let locale:String
    
    let isChatOnly:Bool
    
    // currently unused:
    // let lifetime:Int?
    
    func isOwn() -> Bool {
        return self.creatorId == "users/\(GlobalQuestionData.user_id)"
    }
    
    func isLinkSharingAllowed() -> Bool {
        return self.accessType == 2
    }
    
    static func choicesValid(_ someChoices: [Choice]) -> Bool {
        if (someChoices.count<1) { return false }
        for choice in someChoices {
            if !choice.isValid() { return false }
        }
        return true
    }
    
    func mostRecentActivityDescription(_ completion: @escaping (String?) -> Void) {
        if self.unseenCountChoices > 0 {
            let stringIdentifier = self.unseenCountChoices > 1 ? "x_new_choice" : "new_choice_notification"
            completion(NSString(format: NSLocalizedString(stringIdentifier, comment: "New choices") as NSString, self.unseenCountChoices) as String)
        }  else if self.unseenCountRatings > 0 {
            if(self.unseenCountRatings > 1){
                completion(NSString(format: NSLocalizedString("x-users-have-voted", comment: "") as NSString, self.unseenCountRatings) as String)
            } else{
                Choice.fetchChoices(question: self, choiceId: nil, completion: {choices, error in
                    if let choices = choices {
                        
                        var mostRecentVoting = Date.distantPast
                        var mostRecentVoter:String? = nil
                        
                        let rating_dispatchGroup = DispatchGroup()
                        for choice in choices{
                            rating_dispatchGroup.enter()
                            Rating.ratings(questionId: self.id, choiceId: choice.id, raterId: nil, callbackOnce: true, completion: {ratings, error in
                                if let ratings = ratings{
                                    for rating in ratings{
                                        if(mostRecentVoting.compare(rating.creationDate as Date) == .orderedAscending){
                                            mostRecentVoting = rating.creationDate as Date
                                            mostRecentVoter = rating.raterId
                                        }
                                    }
                                }
                                rating_dispatchGroup.leave()
                            })
                        }
                        
                        rating_dispatchGroup.notify(queue: DispatchQueue.main, execute: {
                            if let mostRecentVoter = mostRecentVoter{
                                User.fetchUsers(questionId: self.id, userId: mostRecentVoter, completion: { users, error in
                                    if let user = users?.first{
                                        let username = !self.isPublic ? user.username : NSLocalizedString("someone", comment: "")
                                        
                                        completion(NSString(format: NSLocalizedString("remote_new_vote2", comment: "") as NSString, username) as String)
                                    } else{
                                        completion(nil)
                                    }
                                })
                            } else{
                                completion(nil)
                            }
                        })
                        
                    }
                })
            }
        } else {
            Comment.fetchComments(questionId: self.id, commentId: nil) { (comments, error) in
                if let mostRecentComment = comments?.last {
                    var lastText = ""
                    if mostRecentComment.photoId != nil {
                        lastText = "📎" + NSLocalizedString("comment_attachment", comment: "Attachment")
                    } else {
                        lastText = "\"\(mostRecentComment.text ?? "")\""
                    }
                    
                    if let invitee = mostRecentComment.invitedMember {
                        User.fetchUsers(questionId: self.id, userId: "users/\(invitee)", completion: { (users, error) in
                            var finalText = lastText
                            if let user = users?.first {
                                finalText = NSString(format: NSLocalizedString("join_notice", comment: "") as NSString, user.username) as String
                            }
                            completion(finalText)
                        })
                    } else{
                        User.fetchUsers(questionId: self.id, userId: mostRecentComment.userId, completion: { (users, error) in
                            var finalText = lastText
                            if let user = users?.first {
                                finalText = "\(!self.isPublic ? user.username : NSLocalizedString("someone", comment: "")): " + lastText
                                
                                if(mostRecentComment.leave && !self.isChatOnly){
                                    finalText = NSString(format: NSLocalizedString("leave_notice", comment: "") as NSString, !self.isPublic ? user.username : NSLocalizedString("someone", comment: "")) as String
                                } else if (mostRecentComment.leave && self.isChatOnly){
                                    finalText = NSString(format: NSLocalizedString("chat_leave_notice", comment: "") as NSString, !self.isPublic ? user.username : NSLocalizedString("someone", comment: "")) as String
                                } else if(mostRecentComment.stop){
                                    finalText = NSString(format: NSLocalizedString("close_notice", comment: "") as NSString, self.isPublic ? "Judge it!" : user.username) as String
                                } else if(mostRecentComment.addedChoice != nil){
                                    finalText = NSString(format: NSLocalizedString("choice_notice", comment: "") as NSString, !self.isPublic ? user.username : NSLocalizedString("someone", comment: "")) as String
                                } else if(mostRecentComment.isCreationNotice && !self.isChatOnly){
                                    finalText = NSString(format: NSLocalizedString("create_notice", comment: "") as NSString, !self.isPublic ? user.username : NSLocalizedString("someone", comment: "")) as String
                                } else if(mostRecentComment.isCreationNotice && self.isChatOnly){
                                    finalText = NSString(format: NSLocalizedString("chat_create_notice", comment: "") as NSString, !self.isPublic ? user.username : NSLocalizedString("someone", comment: "")) as String
                                }
                            }
                            completion(finalText)
                        })
                    }
                } else{
                    completion(nil)
                }
            }
        }
    }
    
    open func unseenCountTotal() -> Int {
        return self.unseenCountComments + self.unseenCountRatings + self.unseenCountChoices
    }
    
    open override var debugDescription : String {
        return String(format: "%@ '%@' with %d unseen things.", super.debugDescription, self.text, self.unseenCountComments + self.unseenCountRatings + self.unseenCountChoices)
    }
    
    init(dictionary: Dictionary<String, Any>) {
        self.id = dictionary["id"] as! String
        self.creatorId = dictionary["creator-id"] as! String
        self.text = dictionary["text"] as? String ?? ""
        self.created = Date(timeIntervalSince1970: Double(dictionary["created"] as? Int ?? 0))
        //        self.lifetime = dictionary["lifetime"] as? Int
        self.accessType = dictionary["access-type"] as? Int ?? 1
        self.followupToId = dictionary["followup-to-id"] as? String
        self.unseenCountComments = dictionary["unseen-count-comments"] as? Int ?? 0
        self.unseenCountChoices = dictionary["unseen-count-choices"] as? Int ?? 0
        self.unseenCountRatings = dictionary["unseen-count-ratings"] as? Int ?? 0
        self.isUnseen = dictionary["unseen?"] as? Bool ?? false
        self.isMuted = dictionary["muted?"] as? Bool ?? false
        self.lastModification = Date(timeIntervalSince1970: Double(dictionary["modified"] as? Int ?? 0))
        self.isClosed = dictionary["stopped?"] as? Bool ?? false
        self.locale = dictionary["locale"] as? String ?? "en"
        self.isPublic = dictionary["public"] as? Bool ?? false
        self.isChatOnly = (dictionary["chat-only"] as? Int ?? 0) == 1
    }
    
    static func fetchQuestions(questionId: String?, alsoCached: Bool = true, callbackOnce: Bool = false, completion: @escaping ([Question]?, NSError?) -> Void) {
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        
        var urlString = Communicator.instance.SERVER_URL + "/api/v2/"
        if let questionId = questionId {
            urlString += questionId
        } else {
            urlString += "questions"
        }
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters, alsoCached: alsoCached, callbackOnce: callbackOnce) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                if let questionsArray = JSON as? Array<Dictionary<String, AnyObject>> {
                    var result = [Question]()
                    for questionDict in questionsArray {
                        let question = Question(dictionary: questionDict)
                        result.append(question)
                    }
                    
                    completion(result, nil)
                } else {
                    completion(nil, nil)
                }
                
            }
        }
    }
    
    static func fetchPublicQuestions(own: Bool = false, count: Int = 100, alsoCached: Bool = true, completion: @escaping ([Question]?, NSError?) -> Void){
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        parameters["public"] = true
        parameters["public-own"] = own
//        parameters["public-count"] = count
        parameters["locale"] = Locale.current.languageCode
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/questions"
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters, alsoCached: alsoCached) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                if let questionsArray = JSON as? Array<Dictionary<String, AnyObject>> {
                    var result = [Question]()
                    for questionDict in questionsArray {
                        let question = Question(dictionary: questionDict)
                        result.append(question)
                    }
                    
                    completion(result, nil)
                } else {
                    completion(nil, nil)
                }
                
            }
        }
    }
    
    static func fetchUserCount(questionId: String, alsoCached: Bool = true, completion: @escaping ((Int?, Error?) -> Void)){
        var parameters = [String: Any]()
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + questionId + "/usercount"
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters, alsoCached: alsoCached) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                if let result = JSON as? Dictionary<String, AnyObject>,
                    let count = result["count"] as? Int {
                    completion(count, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    static func setAccessType(questionId: String, accessType: Int, completion: @escaping ((Bool, Error?) -> Void)) {
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        parameters["access-type"] = accessType
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + questionId
        
        Communicator.manager.request(urlString, method: .patch, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json"]).responseJSON { (response) in
            completion(response.result.error == nil, response.result.error)
        }
    }
    
    static func setStopped(questionId: String, stopped: Bool, completion: @escaping ((Bool, Error?) -> Void)) {
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        parameters["stopped"] = (stopped ? 1 : 0)
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + questionId
        
        Communicator.manager.request(urlString, method: .patch, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json"]).responseJSON { (response) in
            completion(response.result.error == nil, response.result.error)
        }
    }
    
    static func setMuted(questionId: String, muted: Bool, completion: @escaping ((Bool, Error?) -> Void)) {
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        parameters["muted?"] = muted
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + questionId
        
        // I don't know why it's needed to distinguish between muted and !muted
        // and sending header Accept or not.
        Communicator.manager.request(urlString, method: .patch, parameters: parameters, encoding: JSONEncoding.default, headers: !muted ? nil : ["Accept": "application/json", "Content-Type": "application/json"]).responseJSON { (response) in
            completion(response.result.error == nil, response.result.error)
        }
    }
    
    static func removeParticipant(questionId: String, participantId: String, completion: @escaping ((Bool, Error?) -> Void)) {
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + questionId + "/participants/" + "\(participantId.rawId()!)"
        
        Communicator.manager.request(urlString, method: .delete, parameters: parameters, encoding: URLEncoding.queryString, headers: nil /* ["Accept": "application/json"]*/).responseJSON { (response) in
            completion(response.result.error == nil, response.result.error)
        }
    }
    
    fileprivate static func genericMakeSeen(unseenType: String, questionId: String? = nil, completion: @escaping ([String]?, NSError?) -> Void) {
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        
        var urlString = Communicator.instance.SERVER_URL + "/api/v2/unseen"
        if questionId != nil {
            urlString += "/" + questionId!
        }
        urlString += "/" + unseenType
        
        Communicator.manager.request(urlString, method: .delete, parameters: parameters, encoding: URLEncoding.queryString, headers: nil /*["Accept": "application/json"]*/).responseJSON(completionHandler: { (response) in
            if let error = response.result.error {
                completion(nil, error as NSError?)
            } else {
                let resultDict = response.result.value as! Dictionary<String, AnyObject>
                let result = resultDict["invalidated"] as! Array<String>
                completion(result, nil)
            }
        })
    }
    
    // Caution: All means all! Everything for the current user. Nuthin' stays unseen for her.
    static func makeAllSeen(_ completion: @escaping ([String]?, NSError?) -> Void) {
        genericMakeSeen(unseenType: "all", completion: completion)
    }
    
    static func makeCommentsSeen(questionId: String, completion: @escaping ([String]?, NSError?) -> Void) {
        genericMakeSeen(unseenType: "new-comments", questionId: questionId, completion: completion)
    }
    
    static func makeRatingsSeen(questionId: String, completion: @escaping ([String]?, NSError?) -> Void) {
        genericMakeSeen(unseenType: "new-ratings", questionId: questionId, completion: completion)
    }
    
    static func makeChoicesSeen(questionId: String, completion: @escaping ([String]?, NSError?) -> Void) {
        genericMakeSeen(unseenType: "new-choices", questionId: questionId, completion: completion)
    }
    
    static func makeOld(questionId: String, completion: @escaping ([String]?, NSError?) -> Void) {
        genericMakeSeen(unseenType: "new-question", questionId: questionId, completion: completion)
    }
    
    // all of the question's stuff (new choices, new comments, etc.) set to seen:
    static func makeSeen(questionId: String, completion: @escaping ([String]?, NSError?) -> Void) {
        genericMakeSeen(unseenType: "question-all", questionId: questionId, completion: completion)
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
    
    static func createNew(text: String, choicesDictionaries: [[String: Any]], accessType: Int?=1, isPublic:Bool = false, followupQuestionId: String? = nil, chatOnly:Bool = false, completion: @escaping (Question?, NSError?) -> Void) {
        var parameters: [String: Any] = ["user-id": GlobalQuestionData.user_id,
                                         "token": GlobalQuestionData.login_token]
        
        let locale = Locale.current.languageCode
        
        parameters["text"] = text
        parameters["access-type"] = accessType
        parameters["locale"] = locale
        parameters["public"] = isPublic ? 1 : 0
        parameters["chat-only"] = chatOnly ? 1 : 0
        if followupQuestionId != nil {
            parameters["followup-to-id"] = followupQuestionId
        }
        parameters["choices"] = choicesDictionaries
        
        Communicator.manager.request(Communicator.instance.SERVER_URL + "/api/v2/questions",
                                     method: .post,
                                     parameters: parameters,
                                     encoding: JSONEncoding.default,
                                     headers: ["Accept": "application/json", "Content-Type": "application/json"])
            .responseJSON(completionHandler: { (response) in
                if let error = response.result.error {
                    completion(nil, error as NSError?)
                } else {
                    let resultDict = response.result.value as? Dictionary<String, [String: [[String: Any]]]>
                    if let questionDict = (resultDict?["created"]?["questions"])?.first {
                        completion(Question(dictionary: questionDict), nil)
                    }
                }
            })
    }
}

func == (left: Question, right: Question) -> Bool {
    return left.id == right.id
        && (left.lastModification == right.lastModification)
        && left.unseenCountChoices == right.unseenCountChoices
        && left.unseenCountRatings == right.unseenCountRatings
        && left.unseenCountComments == right.unseenCountComments
        && left.isUnseen == right.isUnseen
        && left.isMuted == right.isMuted
        && left.accessType == right.accessType
}

func != (left:Question, right:Question) -> Bool {
    return !(left == right)
}
