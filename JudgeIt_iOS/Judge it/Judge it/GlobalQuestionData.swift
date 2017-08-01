//
//  GlobalQuestionData.swift
//  Judge it
//
//  Created by Daniel Thevessen on 10/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import AudioToolbox

class GlobalQuestionData {
    
    // General app variables that are passed around too often to keep in a single class
    static var questionMap:[Int:Question] = [Int:Question]()
    
    static var ratingChanges = [Int:Int]()
    static var userMap = [Int:User]()
    
    static var user_id:Int = -1
    static var login_token:String = ""
    static var email:String? = nil
    static var phoneNumber:String?
    static var phoneIsSet:Bool = false
    
    static var fbToken:FBSDKAccessToken? = nil
    static var googleToken:GIDGoogleUser? = nil
    static var afterLogout = false
    
    static var premium = false
    static var free_remaining = 0
    
    static let INTRO_VOTING_ID = "questions/6216"
    
//    public static Bitmap tempImage = null;
//    public static WeakHashMap<String, Bitmap> imageCache = new WeakHashMap<>();
//    public static HashMap<Bitmap, Bitmap> circleImageCache = new HashMap<>();
    
//    static var updateMap:[Int:[UpdateTypeWrapper]] = [:]
    
    static var contactSet = Set<Int>()
        
}
