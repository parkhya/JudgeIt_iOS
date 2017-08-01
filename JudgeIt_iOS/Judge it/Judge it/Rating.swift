//
//  Rating.swift
//  Judge it!
//
//  Created by Axel Katerbau on 20.09.16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation
import Alamofire

class Rating : Hashable {
    
    let choiceId: String
    let raterId: String
    let rating: Int
    let creationDate: Date
    
    var hashValue: Int {
        return choiceId.rawId()! + raterId.rawId()!
    }
    
    let dictionary: Dictionary<String, AnyObject>?
    
    init(dictionary: Dictionary<String, AnyObject>) {
        self.dictionary = dictionary
        
        self.choiceId = (dictionary["choice-id"] as! String)
        self.raterId = (dictionary["rater-id"] as! String)
        self.rating = dictionary["rating"] as! Int!
        self.creationDate = Date(timeIntervalSince1970:Double(dictionary["created"] as! Int!))
    }
    
    static func ratings(questionId: String, choiceId: String?, raterId: String?, alsoCached: Bool = true, callbackOnce:Bool = false, queue: DispatchQueue? = nil, completion: @escaping ([Rating]?, NSError?) -> Void) {
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        
        if raterId != nil {
            parameters["rater-id"] = raterId
        }
        
        var urlString = Communicator.instance.SERVER_URL + "/api/v2/" + questionId
        if choiceId != nil {
            urlString += "/" + choiceId!
        }
        urlString += "/ratings"
        
        // TODO: make working for nil choiceId on the server!
        Communicator.manager.getJSONObject(urlString, parameters: parameters, alsoCached: alsoCached, callbackOnce: callbackOnce, queue: queue) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                if let ratingsArray = JSON as? Array<Dictionary<String, AnyObject>> {
                    var result = [Rating]()
                    for ratingDict in ratingsArray {
                        let rating = Rating(dictionary: ratingDict)
                        result.append(rating)
                    }
                    
                    completion(result, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    static func rate(questionId: String, ratingDictionaries:[[String:Any]], completion: @escaping (NSError?) -> Void) {
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["rater-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        parameters["votes"] = ratingDictionaries
        
        var urlString = Communicator.instance.SERVER_URL + "/api/v2/"
        urlString += questionId + "/ratings"
        
        
        Communicator.manager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).responseJSON(completionHandler: { response in
            
            var error:NSError? = nil
            let rating_dispatchGroup = DispatchGroup()
            for dict in ratingDictionaries{
                rating_dispatchGroup.enter()
                let choiceId = dict["choice-id"] as! String
                
                ratings(questionId: questionId, choiceId: choiceId, raterId: "users/\(GlobalQuestionData.user_id)", alsoCached: false) { (ratings, _) in
                    error = error ?? (response.result.error as NSError?)
                    rating_dispatchGroup.leave()
                }
            }
            
            rating_dispatchGroup.notify(queue: DispatchQueue.main, execute: {
                completion(error)
            })
        })
    }
    
    
    static func addRatings(questionId: String, ratingDictionaries: [[String: Any]], completion: @escaping (NSError?) -> Void) {
        let queue: [[String: Any]] = ratingDictionaries
        
        if(queue.count > 0){
            self.rate(questionId: questionId, ratingDictionaries: queue, completion: { (error) in
                completion(error)
            })
        }
    }
    
}

func == (left: Rating, right: Rating) -> Bool {
    return left.choiceId == right.choiceId && left.raterId == right.raterId && (left.creationDate == right.creationDate)
}

func != (left:Rating, right:Rating) -> Bool {
    return !(left == right)
}
