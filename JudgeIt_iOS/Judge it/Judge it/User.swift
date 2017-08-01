//
//  User.swift
//  Judge it
//
//  Created by Daniel Thevessen on 10/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import Alamofire
import libPhoneNumber_iOS
import CoreTelephony
import Contacts

open class User : UserListItem, Hashable {
    
    // Hashable
    open var hashValue: Int {
        return id().hashValue
    }
    fileprivate (set) var user_id:Int
    
    
    // UserListItem
    @objc var title: String {
        return username // please remove me!
    }
    @objc var description: String {
        return statusText
    }
    @objc var picturePath:String? // legacy, use photoId for new API
    @objc var picture: UIImage?
    
    let photoId: String?
    let emailAddress: String?
    
    var username:String
    var statusText:String
    var relation:ContactRelation?
    
    let phoneNumberHash: String?
    let allNotificationsMuted: Bool
    let privacyMode:Bool
    
    init(user_id:Int, username:String, statusText:String, picturePath:String?, relation:ContactRelation, privacyMode: Bool = false){
        self.user_id = user_id
        self.username = username
        self.statusText = statusText
        self.picturePath = picturePath
        self.relation = relation
        self.photoId = nil
        self.emailAddress = nil
        self.allNotificationsMuted = false
        self.phoneNumberHash = nil
        self.privacyMode = privacyMode
    }
    
    convenience init(user_id:Int, username:String, statusText:String, picturePath:String?){
        self.init(user_id: user_id, username: username, statusText: statusText, picturePath: picturePath, relation: ContactRelation.UNKNOWN)
    }
    
    @objc func isOrderedBefore(_ other: UserListItem) -> Bool {
        if(relation == ContactRelation.BLACKLIST){
            return false
        }
        if((other as? User)?.relation == ContactRelation.BLACKLIST){
            return true
        }
        
        if((other as? UserGroup) != nil){
            return false
        }
        
        return title.lowercased() < other.title.lowercased()
    }
    
    @objc func id() -> String {
        return "users/\(user_id)"
    }
    
    init(dictionary: Dictionary<String, Any>) {
        self.user_id = (dictionary["id"] as! String).rawId()!
        self.username = dictionary["name"] as? String ?? ""
        self.photoId = dictionary["photo-id"] as? String
        self.statusText = dictionary["status-text"] as? String ?? ""
        if let rawRelation = dictionary["relation-type"] as? Int {
            self.relation = ContactRelation(rawValue: rawRelation)
        } else {
            self.relation = nil
        }
        
        self.emailAddress = dictionary["email-address"] as? String
        
        if let rawAllMuted = dictionary["all-notifications-muted?"] as? Int {
            self.allNotificationsMuted = rawAllMuted != 0 ? true : false
        } else {
            self.allNotificationsMuted = false
        }
        
        if let numberCandidate = dictionary["phone-number-hash"] as? String, numberCandidate.length > 0 {
            self.phoneNumberHash = numberCandidate
        } else {
            self.phoneNumberHash = nil
        }
        
        self.privacyMode = (dictionary["privacymode"] as? Int ?? 0) == 1
    }
    
    static func fetchContacts(_ userId: String, alsoCached: Bool = true, completion: @escaping ([User]?, Error?) -> Void) {
        let parameters: [String: Any] = ["token": GlobalQuestionData.login_token]
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + userId + "/contacts/users"
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters, alsoCached: alsoCached) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                var result = [User]()
                if let usersArray = JSON as? Array<Dictionary<String, AnyObject>> {
                    for userDict in usersArray {
                        let user = User(dictionary: userDict)
                        result.append(user)
                    }
                    completion(result, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    static func addToContacts(userIds: [String], relationType: ContactRelation, completion: @escaping (Error?) -> Void) {
        let parameters: [String: Any] = ["token": GlobalQuestionData.login_token, "user-id": GlobalQuestionData.user_id , "user-ids": userIds , "relation-type": relationType.rawValue ]
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(GlobalQuestionData.user_id)" + "/contacts/user-ids"
        
        Communicator.manager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).response { (response) in
            if let error = response.error {
                completion(error)
            } else {
                completion(nil)
            }
        }
        
    }
    
    static func removeFromContacts(userIds: [String], completion: @escaping (Error?) -> Void) {
        let parameters: [String: Any] = ["token": GlobalQuestionData.login_token , "user-id": GlobalQuestionData.user_id , "user-ids": userIds ]
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(GlobalQuestionData.user_id)" + "/contacts/user-ids"
        
        Communicator.manager.request(urlString, method: .delete, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).response { (response) in
            if let error = response.error {
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
    
    /* Retrieves user(s) related to a question.*/
    static func fetchUsers(questionId: String? = nil, userId: String? = nil, alsoCached: Bool = true, callbackOnce:Bool = false, loadIfModifiedSinceDate: Date? = Date(timeIntervalSinceNow: -10), queue: DispatchQueue? = nil, completion: @escaping ([User]?, Error?) -> Void) {
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        
        var urlString = Communicator.instance.SERVER_URL + "/api/v2/"
        guard questionId != nil || userId != nil else {
            return
        }
        
        if let userId = userId, let questionId = questionId {
            urlString += questionId + "/" + userId
        } else if let questionId = questionId {
            urlString += questionId + "/users"
        } else {
            urlString += userId!
            parameters["user-left"] = true
        }
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters, alsoCached: alsoCached, callbackOnce: callbackOnce, loadIfModifiedSinceDate: loadIfModifiedSinceDate as NSDate?, queue: queue) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                var result = [User]()
                if let usersArray = JSON as? Array<Dictionary<String, AnyObject>> {
                    for userDict in usersArray {
                        let user = User(dictionary: userDict)
                        result.append(user)
                    }
                    completion(result, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    static func patchProfile(username: String? = nil, statusText: String? = nil, phoneNumber: String? = nil, photo: UIImage? = nil, allNotificationsMuted: Bool? = nil, privacyMode: Bool? = nil, completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
            var parameters = [String: Any]()
            
            if let username = username, username.characters.count > 0 {
                parameters["name"] = username
            }
            
            if let statusText = statusText, statusText.characters.count > 0 {
                parameters["status-text"] = statusText
            }
            
            if let phoneNumber = phoneNumber, let hashedPhoneNumber = phoneNumber.hashedPhoneNumber() {
                parameters["phone-number-hash"] = (phoneNumber.length>0 ? hashedPhoneNumber : "")
            }
            
            if let allNotificationsMuted = allNotificationsMuted {
                parameters["all-notifications-muted?"] = allNotificationsMuted
            }
            
            if let privacyMode = privacyMode {
                parameters["privacymode"] = privacyMode
            }
            
            if let photo = photo {
                let preparedphoto = photo.resizeToWidth(500)
                let imageData = UIImageJPEGRepresentation(preparedphoto, 0.95)
                let base64String = imageData?.base64EncodedString(options: .lineLength64Characters)
                
                parameters["photo-base64"] = base64String
            }
            
            DispatchQueue.main.async {
                if parameters.count > 0 {
                    parameters["user-id"] = GlobalQuestionData.user_id
                    parameters["token"] = GlobalQuestionData.login_token
                    
                    let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(GlobalQuestionData.user_id)" + "/profile"
                    Communicator.manager.request(urlString, method: .patch, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).response {response in
                        completion(response.error)
                    }
                } else {
                    completion(nil);
                }
            }
        }
    }
    
    static func fetchProfile(alsoCached: Bool = true, completion: @escaping (User?, Error?) -> Void) {
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(GlobalQuestionData.user_id)" + "/profile"
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters, alsoCached: alsoCached) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                if let usersArray = JSON as? Array<Dictionary<String, AnyObject>>, let userDict = usersArray.first {
                    let user = User(dictionary: userDict)
                    completion(user, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    // term like "name:ax*"
    static func searchUsers(term: String, completion: @escaping ([User]?, Error?) -> Void) {
        var parameters = [String: Any]()
        
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        parameters["filter"] = term
        
        let urlString = Communicator.instance.SERVER_URL + "/api/v2/users"
        
        Communicator.manager.getJSONObject(urlString, parameters: parameters) { (JSON, error) in
            if error != nil {
                completion(nil, error)
            } else {
                var result = [User]()
                if let usersArray = JSON as? Array<Dictionary<String, Any>> {
                    for userDict in usersArray {
                        let user = User(dictionary: userDict)
                        result.append(user)
                    }
                    completion(result, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
    
    static func dictionariesFromParticipants<T:Sequence>(_ participants: T) -> [[String: Any]] where T.Iterator.Element == User {
        var result = [[String: Any]]()
        for participant in participants {
            var participantDictionary = [String: Any]();
            participantDictionary["participant-id"] = participant.id()
            participantDictionary["muted?"] = false
            result.append(participantDictionary)
        }
        
        return result
    }
    
    static func addParticipants(questionId: String, participantsDictionaries: [[String: Any]], completion: @escaping (Any?, NSError?) -> Void) {
        
        var results = [Any]()
        var queue: [[String: Any]] = participantsDictionaries // copy?
        
        func addNext() {
            
            if let participantDictionary = queue.first {
                queue.removeFirst() // better would be: queue.removeObject(choiceDictionary)
                var parameters = participantDictionary
                parameters["user-id"] = GlobalQuestionData.user_id
                parameters["token"] = GlobalQuestionData.login_token
                
                Communicator.manager.request(Communicator.instance.SERVER_URL + "/api/v2/" + questionId + "/participants", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).responseJSON { (response) in
                    if let error = response.result.error {
                        completion(nil, error as NSError?)
                    } else {
                        if let resultDict = response.result.value as? [String : Any],
                            let createdDict = resultDict["created"] as? [String : Any],
                            let participantsArray = createdDict["participants"] as? Array<[String : Any]>,
                            let participantDict = participantsArray.first {
                            //let participant = User(dictionary: participantDict)
                            results.append(participantDict)
                        }
                        
                        addNext()
                    }
                }
            } else {
                completion(results, nil)
            }
        }
        
        addNext()
    }
    
    func fetchPhoto(_ completion: @escaping (UIImage?, Error?) -> Void) {
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
    
    
    // TODO: Reimplement with Contacts framework
    static func addMatchingPhoneContacts(_ completion: @escaping ([String]?, Error?) -> Void) {
        
        let contactStore = CNContactStore()
        let requestedAttrs = [CNContactPhoneNumbersKey] as [Any]
        contactStore.requestAccess(for: .contacts, completionHandler: { (granted, error) -> Void in
            do {
                if granted {
                    let predicate = CNContact.predicateForContactsInContainer(withIdentifier: try contactStore.containers(matching: nil).first!.identifier)
                    let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: requestedAttrs as! [CNKeyDescriptor])
                    
                    let hashedPhoneNumbers = contacts.reduce([String]()) { (hashedPhoneNumbersSoFar, contact) in
                        let phoneNumbers = contact.phoneNumbers
                        var result = hashedPhoneNumbersSoFar
                        
                        for phoneNumber in phoneNumbers {
                            if let hashedPhoneNumer = phoneNumber.value.stringValue.hashedPhoneNumber() {
                                result.append(hashedPhoneNumer)
                            }
                        }
                        
                        return result
                    }
                    
                    var parameters = [String : Any]()
                    parameters["user-id"] = GlobalQuestionData.user_id
                    parameters["token"] = GlobalQuestionData.login_token
                    parameters["phone-number-hashes"] = hashedPhoneNumbers
                    
                    let urlString = Communicator.instance.SERVER_URL + "/api/v2/" + "users/\(GlobalQuestionData.user_id)" + "/contacts/befriend-with-phone-numbers"
                    
                    Communicator.manager.request(urlString, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: ["Accept": "application/json", "Content-Type": "application/json"]).responseJSON { (response) in
                        if let error = response.result.error {
                            completion(nil, error)
                        } else {
                            if let resultDict = response.result.value as? [String : Any],
                                let addedContactUserIdsArray = resultDict["added-user-ids"] as? Array<String> {
                                completion(addedContactUserIdsArray, nil)
                            } else {
                                completion(nil, nil)
                            }
                        }
                    }
                }
            } catch {
                
            }
        })
    }
}

public func == (left: User, right: User) -> Bool {
    return left.user_id == right.user_id
}

func != (left:User, right:User) -> Bool {
    return !(left == right)
}

let phoneRegion = { () -> String in
    let temp = CTTelephonyNetworkInfo().subscriberCellularProvider?.isoCountryCode ?? "DE"
    return temp.substring(to: temp.index(temp.startIndex, offsetBy: 2))
}()
let phoneUtil = NBPhoneNumberUtil()
let phoneFormatter = NBAsYouTypeFormatter(regionCode: phoneRegion)

extension String {
    func hashedPhoneNumber() -> String? {
        var result: String? = nil
        
        do {
            let parsedPhoneNumber: NBPhoneNumber = try phoneUtil.parse(self, defaultRegion: phoneRegion)
            if phoneUtil.isValidNumber(parsedPhoneNumber) {
                let formattedPhoneNumber: String = try phoneUtil.format(parsedPhoneNumber, numberFormat: .E164)
                
                let saltedPhoneNumber = (formattedPhoneNumber + "muchsalt") as NSString
                result = saltedPhoneNumber.sha256() as String
            }
        } catch {}
        
        return result
    }
}
