//
//  UserGroup.swift
//  Judge it
//
//  Created by Daniel Thevessen on 13/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import UIKit
import Alamofire

class UserGroup : UserListItem, Hashable{
    
    // UserListItem
    @objc var title: String
    let photoId: String?
    let creatorName: String?
    
    @objc var description:String {
        var memberSummary = ""
        for (index, user) in self.memberList.enumerated(){
            memberSummary += user.username
            if(index < self.memberList.endIndex-1){
                memberSummary += " - "
            }
        }
        return memberSummary
    }
    
    @objc var picturePath:String?
    @objc var picture: UIImage?
    
    // Hashable
    internal var hashValue: Int {
        return id().hashValue
    }
    
    var memberList:[User]
    fileprivate (set) var group_id:Int
    fileprivate (set) var creator_id:Int
    
    init(group_id:Int, creator_id:Int, groupName:String, memberList:[User], picturePath:String? = nil, photoId:String? = nil){
        self.group_id = group_id
        title = groupName
        self.memberList = memberList
        self.picturePath = picturePath
        self.photoId = photoId
        self.creator_id = creator_id
        self.creatorName = nil
    }
    
    @objc func id() -> String {
        return "groups/"+String(group_id)
    }
    
    @objc func isOrderedBefore(_ other: UserListItem) -> Bool {
        if((other as? User)?.relation == ContactRelation.BLACKLIST){
            return true
        }
        if((other as? UserGroup) == nil){
            return true
        }
        
        return title.lowercased() < other.title.lowercased()
    }
    
    init(dictionary: Dictionary<String, AnyObject>) {
        self.group_id = (dictionary["id"] as! String).rawId()!
        self.title = dictionary["name"] as? String ?? ""
        self.photoId = dictionary["photo-id"] as? String
        self.picturePath = nil
        self.creator_id = (dictionary["creator-id"] as! String).rawId()!
        self.creatorName = dictionary["creator-name"] as? String
        self.memberList = []
    }
    
    func addMembers(memberIds: [String], completion: @escaping (Error?) -> Void) {
        let parameters: [String: Any] = ["token": GlobalQuestionData.login_token , "user-id": GlobalQuestionData.user_id , "member-ids": memberIds ]
        var urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(self.creator_id)"
        urlString += "/contacts/" + self.id() + "/user-ids"
        
        Communicator.manager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).response { (response) in
            if let error = response.error {
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
    
    func removeMembers(memberIds: [String], completion: @escaping (Error?) -> Void) {
        let parameters: [String: Any] = ["token": GlobalQuestionData.login_token , "user-id": GlobalQuestionData.user_id , "member-ids": memberIds ]
        var urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(self.creator_id)"
        urlString += "/contacts/" + self.id() + "/user-ids"
        
        Communicator.manager.request(urlString, method: .delete, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).response { (response) in
            if let error = response.error {
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
    
    func fetchMemberIds(_ completion: @escaping ([String]?, Error?) -> Void) {
        let parameters: [String: Any] = ["token": GlobalQuestionData.login_token , "user-id": GlobalQuestionData.user_id ]
        var urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(self.creator_id)"
        urlString += "/contacts/" + self.id() + "/user-ids"
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                if let userIds = JSON as? Array<String> {
                    completion(userIds, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    func fetchMembers(_ completion: @escaping ([User]?, Error?) -> Void) {
        let parameters: [String: Any] = ["token": GlobalQuestionData.login_token , "user-id": GlobalQuestionData.user_id ]
        var urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(self.creator_id)"
        urlString += "/contacts/" + self.id() + "/users"
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                if let userDicts = JSON as? Array<[String: Any]> {
                    let result = userDicts.map({ (userDict) -> User in
                        return User(dictionary: userDict)
                    })
                    self.memberList = result // cache result
                    completion(result, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    static func fetchUserGroups(_ userId: String, alsoCached: Bool = true, completion: @escaping ([UserGroup]?, Error?) -> Void) {
        let parameters: [String: Any] = ["token": GlobalQuestionData.login_token , "user-id": GlobalQuestionData.user_id ]
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + userId + "/contacts/groups"
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters, alsoCached: alsoCached) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                var result = [UserGroup]()
                if let userGroupsArray = JSON as? Array<Dictionary<String, AnyObject>> {
                    for userGroupDict in userGroupsArray {
                        let userGroup = UserGroup(dictionary: userGroupDict)
                        result.append(userGroup)
                    }
                    completion(result, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    static func fetchUserGroupMemberships(_ userId: String, alsoCached: Bool = true, completion: @escaping ([UserGroup]?, Error?) -> Void) {
        let parameters: [String: Any] = ["token": GlobalQuestionData.login_token , "user-id": GlobalQuestionData.user_id ]
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + userId + "/contacts/group-memberships"
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters, alsoCached: alsoCached) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                var result = [UserGroup]()
                if let userGroupsArray = JSON as? Array<Dictionary<String, AnyObject>> {
                    for userGroupDict in userGroupsArray {
                        let userGroup = UserGroup(dictionary: userGroupDict)
                        result.append(userGroup)
                    }
                    completion(result, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    func fetchPhoto(_ completion: @escaping (UIImage?, Error?) -> Void) {
        if let photoId = self.photoId, let url = URL(string: Communicator.instance.SERVER_URL + "/cdn/" + photoId + "?uid=\(GlobalQuestionData.user_id)&ltk=\(GlobalQuestionData.login_token)") {
            let urlRequest = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20).urlRequest
            Communicator.imageDownloader.download(urlRequest!) { response in
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
    
    func setPhoto(_ photo: UIImage, completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
            var parameters: [String: Any] = ["token": GlobalQuestionData.login_token, "user-id": GlobalQuestionData.user_id]
            
            let preparedphoto = photo.resizeToWidth(500)
            let imageData = UIImageJPEGRepresentation(preparedphoto, 0.95)
            let base64String = imageData?.base64EncodedString(options: .lineLength64Characters)
            
            parameters["photo-base64"] = base64String
            
            DispatchQueue.main.async {
                var urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(self.creator_id)"
                urlString += "/contacts/" + self.id() + "/photo"
                
                Communicator.manager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).response { (response) in
                    if let error = response.error {
                        completion(error)
                    } else {
                        if let photoId = self.photoId, let url = NSURL(string: Communicator.instance.SERVER_URL + "/cdn/" + photoId + "?uid=\(GlobalQuestionData.user_id)&ltk=\(GlobalQuestionData.login_token)") {
                            let urlRequest = NSURLRequest(url: url as URL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
                            Communicator.imageDownloader.imageCache!.removeImage(for: urlRequest as URLRequest, withIdentifier: nil)
                            Communicator.imageDownloader.sessionManager.session.configuration.urlCache?.removeCachedResponse(for: urlRequest as URLRequest)
                        }
                        completion(nil)
                    }
                }
            }
        }
    }
    
    func setName(_ name: String, completion: @escaping (Error?) -> Void) {
        var parameters: [String: Any] = ["token": GlobalQuestionData.login_token, "user-id": GlobalQuestionData.user_id]
        parameters["name"] = name
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(self.creator_id)" + "/contacts/" + self.id() + "/name"
        
        Communicator.manager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).response { (response) in
            if let error = response.error {
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
    
    static func addGroup(_ name: String, completion: @escaping (UserGroup?, Error?) -> Void) {
        var parameters = [String: Any]()
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        parameters["name"] = name
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(GlobalQuestionData.user_id)" + "/contacts/groups"
        
        Communicator.manager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).responseJSON { (response) in
            if let error = response.result.error {
                completion(nil, error)
            } else {
                let resultDictionary: Dictionary<String, AnyObject> = response.result.value as! Dictionary<String, AnyObject>
                let createdDict = resultDictionary["created"] as! Dictionary<String, AnyObject>
                let groupsArray = createdDict["groups"] as! Array<AnyObject>
                let groupsDict = groupsArray.first as! Dictionary<String, AnyObject>
                let userGroup = UserGroup(dictionary: groupsDict)
                completion(userGroup, nil)
            }
        }
    }
    
    func deleteGroup(_ completion: @escaping (Error?) -> Void) {
        let parameters: [String: Any] = ["token": GlobalQuestionData.login_token , "user-id": GlobalQuestionData.user_id ]
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(GlobalQuestionData.user_id)" + "/contacts/" + self.id()
        
        Communicator.manager.request(urlString, method: .delete, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).response { (response) in
            if let error = response.error {
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
}

func == (left: UserGroup, right: UserGroup) -> Bool {
    return left.group_id == right.group_id
        && left.title == right.title
        && left.photoId == right.photoId
}

func != (left: UserGroup, right: UserGroup) -> Bool {
    return !(left == right)
}
