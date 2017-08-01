//
//  AppDelegate.swift
//  Judge it
//
//  Created by Daniel Thevessen on 07/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import UIKit
import CoreData
import Adjust
import IQKeyboardManagerSwift
import AudioToolbox
import AVFoundation
import Alamofire
import SwiftyJSON
import AlamofireNetworkActivityLogger

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static let NewDataDidBecomeAvailableNotification = "NewDataDidBecomeAvailableNotification"
    
    var window: UIWindow?
    
    let GCM_TOPICS = ["global"]
    var connectedToGCM = false
    var subscribedToTopic = false
    var gcmSenderID: String?
    static var registrationToken: String?
    var registrationOptions = [String: AnyObject]()
    
    static func logout() {
        GlobalQuestionData.user_id = -1
        GlobalQuestionData.login_token = ""
        GlobalQuestionData.afterLogout = true
        GlobalQuestionData.email = nil
        GlobalQuestionData.phoneIsSet = false
        
        GlobalQuestionData.fbToken = nil
        FBSDKLoginManager().logOut()
        GlobalQuestionData.googleToken = nil
        GIDSignIn.sharedInstance().signOut()
        GIDSignIn.sharedInstance().disconnect()
        
        let prefs = UserDefaults.standard
        
        // Do not wait for the Logout call to finish. Do not care, if it fails:
        let request = TaskCollection.initRequest(RequestType.LOGOUT)
        Communicator.instance.communicateWithServer(request, completion: nil) // consistently fails
        
        // Remove all user defaults:
        prefs.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        prefs.setSecretObject(nil, forKey: "pref_pass")
        prefs.setSecretObject(nil, forKey: "current_login_token")
        
        print("Logout done. Redirecting to login page...")
        
        let window = UIApplication.shared.keyWindow!
        for view in window.subviews {
            view.removeFromSuperview()
        }
        
        let rootNavigationController: UIViewController = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "LoginViewController")
        window.rootViewController = rootNavigationController
    }
    
    func unauthorizedRequestDidHappenNotification() {
        let alertController = UIAlertController(title: nil, message: NSLocalizedString("server_error_relog", comment: ""), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: { (action) in
            AppDelegate.logout()
        }))
        
        if let rootTabBarController = AppDelegate.rootTabBarController {
            rootTabBarController.present(alertController, animated: true, completion: nil)
        } else {
            AppDelegate.logout()
        }
    }
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        UserDefaults.standard.setValue(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        UserDefaults.standard.setSecret("somerandomobfuscationsecret")
        
        let prefs = UserDefaults.standard
        GlobalQuestionData.login_token = prefs.secretObject(forKey: "current_login_token") as? String ?? GlobalQuestionData.login_token
        GlobalQuestionData.user_id = prefs.object(forKey: "current_user_id") as? Int ?? GlobalQuestionData.user_id
        
        
        //        // Mock an external push notification:
        //        let plistString = "{\nwmc={action=\"new comment\";question-id=2667;comment-id=9404;};\naps={badge:2; alert={loc-args=(\"d.theisen\",\"Ggg\"); loc-key=\"remote_new_comment\";}; sound=\"default\";\n};\n}"
        //        if let plistData = plistString.dataUsingEncoding(NSUTF8StringEncoding) {
        //            do {
        //                let plist = try NSPropertyListSerialization.propertyListWithData(plistData,  options: .Immutable, format: nil)
        //                    as! [String:AnyObject]
        //                self.application(application, didReceiveRemoteNotification: plist, fetchCompletionHandler: { (result) in
        //                    print("notified with plist: \(plistString)")
        //                })
        //
        //            } catch{
        //                print("Error reading plist: \(error)")
        //            }
        //        }
        
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        NotificationCenter.default.addObserver(self, selector: #selector(unauthorizedRequestDidHappenNotification), name: NSNotification.Name(rawValue: UnauthorizedRequestDidHappenNotification), object: nil)
        
        #if DEBUG
//             NetworkActivityLogger.shared.startLogging()
        #endif
        
        // Set Navigation bar style for application
        UINavigationBar.appearance().barTintColor = UIColor.judgeItPrimaryColor
        UINavigationBar.appearance().tintColor = UIColor.white
        UINavigationBar.appearance().titleTextAttributes = [NSForegroundColorAttributeName : UIColor.white, NSFontAttributeName: UIFont(name: "Amatic-Bold", size: 28)!]
        
        
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().tintColor = UIColor.white
        UITabBarItem.appearance().setTitleTextAttributes([NSFontAttributeName: UIFont(name: "Amatic-Bold", size: 14)!], for: UIControlState())
        UIBarButtonItem.appearance().setTitleTextAttributes([NSForegroundColorAttributeName: UIColor.white], for: UIControlState())
        //        UITabBar.appearance().backgroundColor = GlobalQuestionData.primaryColor
        
        IQKeyboardManager.sharedManager().enable = true
        IQKeyboardManager.sharedManager().enableAutoToolbar = false
        
        FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
        // Configure the Google context: parses the GoogleService-Info.plist, and initializes
        // the services that have entries in the file
        var configureError:NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        assert(configureError == nil, "Error configuring Google services: \(configureError)")
        
        GIDSignIn.sharedInstance().serverClientID = "30181179098-9t63o43dnpslfc13vq9nmedenscug42r.apps.googleusercontent.com"
        
        // Google Analytics
        let gai = GAI.sharedInstance()
        gai?.trackUncaughtExceptions = true
        gai?.dispatchInterval = 120
        gai?.logger.logLevel = GAILogLevel.warning
//        #if DEBUG
//            gai?.logger.logLevel = GAILogLevel.verbose
//        #endif
        _ = gai?.tracker(withTrackingId: "UA-70716735-1")
        
        // Register for remote notifications
        let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
        application.registerUserNotificationSettings(settings)
        application.registerForRemoteNotifications()
        
        let adjustToken = "q5gkipl9981s"
        var environment = ADJEnvironmentProduction
        #if DEBUG
            environment = ADJEnvironmentSandbox
        #endif
        let adjustConfig = ADJConfig(appToken: adjustToken, environment: environment)
        adjustConfig?.logLevel = ADJLogLevelWarn
        Adjust.appDidLaunch(adjustConfig)
        
        if let remoteNotification = launchOptions?[UIApplicationLaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
            handleNotification(remoteNotification)
        } else if launchOptions != nil {
            handleNotification(launchOptions!)
        }
        
        //        handleNotification(["wmc" : [
        //            "action" : "invite group",
        //            "question-id" : 2376,
        //            ]])
        return true
    }
    
    func application( _ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken
        deviceToken: Data ) {
        
        // APNS Token, NOT GCM!!
        let tokenChars = (deviceToken as NSData).bytes.bindMemory(to: CChar.self, capacity: deviceToken.count)
        var registrationToken = ""
        for i in 0..<deviceToken.count {
            registrationToken += String(format: "%02.2hhx", arguments: [tokenChars[i]])
        }
        AppDelegate.registrationToken = registrationToken
        print("Registration Token: \(registrationToken)")
        
        if(AppDelegate.registrationToken != nil){
            GCMRegisterTask.gcmRegisterTask(AppDelegate.registrationToken!, delegate: RegistrationDelegate())
        }
    }
    
    func application( _ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError
        error: Error ) {
        print("Registration for remote notification failed with error: \(error.localizedDescription)")
        // As badge counts are currently only set be push notifications, avoiding having wrong badge
        // counts when they are not available:
        application.applicationIconBadgeNumber = 0
    }
    
    func registrationHandler(_ registrationToken: String?, error: NSError?) {
        if (registrationToken != nil) {
            AppDelegate.registrationToken = registrationToken
            print("Registration Token: \(registrationToken)")
            
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
                if(AppDelegate.registrationToken != nil){
                    GCMRegisterTask.gcmRegisterTask(AppDelegate.registrationToken!, delegate: RegistrationDelegate())
                }
            })
            
            //            self.subscribeToTopics()
        } else {
            print("Registration to APNS failed with error: \(error?.localizedDescription)")
        }
    }
    
    class RegistrationDelegate : GCMRegisterTask.GCMTaskDelegate{
        override func onPostExecute(_ result: Bool) {
            if(!result){
                print("Sending gcm token to backend failed!")
                let tracker = GAI.sharedInstance().defaultTracker
                tracker?.send(GAIDictionaryBuilder.createException(withDescription: "Sending token to backend failed", withFatal: false).build() as NSDictionary as! [AnyHashable: Any])
            }
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler handler: @escaping (UIBackgroundFetchResult) -> Void) {
        var isSilentNotification = false
        if let aps = userInfo["aps"] as? [String: Any] {
            if aps["content-available"] as? Int == 1 {
                isSilentNotification = true
            }
            
            if let badgeCount = aps["badge"] as? Int {
                application.applicationIconBadgeNumber = badgeCount
            }
        }
        
        if userInfo["wmc"] != nil {
            if isSilentNotification {
                NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: self, userInfo: userInfo)
            } else if application.applicationState != UIApplicationState.active {
                handleNotification(userInfo)
            }
        }
        
        handler(UIBackgroundFetchResult.newData);
    }
    
    static var notificationUserInfoToUseAfterLogin: [AnyHashable: Any]?
    static var rootTabBarController: JITabBarController?
    
    func showQuestion(_ questionId: String, inTab: VotingViewController.TabTag) {
        Question.fetchQuestions(questionId: questionId, alsoCached: true, callbackOnce: true) { (questions, error) in
            if let question = questions?.first {
                // select "home" tab:
                var homeTabIndex: Int = question.isPublic ? 1 : 0
                homeTabIndex = question.isChatOnly ? 2 : homeTabIndex
                AppDelegate.rootTabBarController?.selectedIndex = homeTabIndex
            } else {
                AppDelegate.rootTabBarController?.selectedIndex = 0
            }
            
            // pull all but first from tab's nav controller (voting list view controller visible) :
            if let navController = AppDelegate.rootTabBarController?.selectedViewController as? UINavigationController {
                navController.popToRootViewController(animated: false)
                
                if let questionListViewController = navController.topViewController as? VotingListViewController {
                    questionListViewController.selectQuestion(questionId, tab: inTab)
                }
            }
        }
    }
    
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        if let actionDict = userInfo["wmc"] as? [String:AnyObject],
            let action = actionDict["action"] as? String {
            
            if AppDelegate.isLoggedIn() && AppDelegate.rootTabBarController != nil {
                AppDelegate.notificationUserInfoToUseAfterLogin = nil
                
                var questionId: String?
                if let rawQuestionId = actionDict["question-id"] as? Int {
                    questionId = "questions/\(rawQuestionId)"
                } else if let rawQuestionId = actionDict["question-id"] as? String {
                    questionId = "questions/\(rawQuestionId)"
                }
                
                switch(action) {
                case "new question":
                    if let questionId = questionId {
                        showQuestion(questionId, inTab: VotingViewController.TabTag.voting)
                    }
                    break
                    
                case "new ratings":
                    if let questionId = questionId {
                        showQuestion(questionId, inTab: VotingViewController.TabTag.results)
                    }
                    break
                    
                case "new comment":
                    if let questionId = questionId {
                        showQuestion(questionId, inTab: VotingViewController.TabTag.chat)
                    }
                    break
                    
                case "invite group":
                    let contactsTabIndex: Int = (AppDelegate.rootTabBarController?.indexOfItemWithTag(JITabBarController.TabTag.contacts.rawValue))!
                    AppDelegate.rootTabBarController?.selectedIndex = contactsTabIndex
                    break
                    
                case "new choice":
                    if let questionId = questionId {
                        showQuestion(questionId, inTab: VotingViewController.TabTag.voting)
                    }
                    break
                    
                default:
                    print("Unrecognized action \(action) received. Ignoring.")
                    break
                }
            } else {
                AppDelegate.notificationUserInfoToUseAfterLogin = userInfo
            }
        }
    }
    
    func joinQuestion(_ broadcastURL: URL) {
        
        func showJoinQuestionError() {
            let alertController = UIAlertController(title: "Error", message: NSLocalizedString("joined_question_error", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default, handler: nil))
            
            if let rootTabBarController = AppDelegate.rootTabBarController {
                rootTabBarController.present(alertController, animated: true, completion: nil)
            }
        }
        
        if let components = URLComponents(url: broadcastURL, resolvingAgainstBaseURL: true),
            let rawQuestionId = IDObfuscator.deObfuscate(components.queryItems?.filter({$0.name == "ref"}).first?.value) {
            Question.fetchQuestions(questionId: "questions/\(rawQuestionId)", alsoCached: false, completion: { (questions, error) in
                if let question = questions?.first {
                    
                    var participantDicts = [[String: Any]]()
                    var participantDictionary = [String: Any]();
                    participantDictionary["participant-id"] = "users/\(GlobalQuestionData.user_id)"
                    participantDictionary["muted?"] = false
                    participantDicts.append(participantDictionary)
                    
                    User.addParticipants(questionId: question.id, participantsDictionaries: participantDicts, completion: { (some, error) in
                        if error == nil {
                            self.showQuestion(question.id, inTab: VotingViewController.TabTag.voting)
                        } else {
                            showJoinQuestionError()
                        }
                    })
                } else {
                    showJoinQuestionError()
                }
            })
        } else {
            showJoinQuestionError()
        }
    }
    
    func application(_ application:UIApplication, handleOpen url:URL) -> Bool {
        print(url)
        if url.scheme == "judgeit" || url.host == "get.judge-it.net" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                let dataString = components.queryItems?.filter({$0.name == "al_applink_data"}).first?.value{
                
                if let data = dataString.data(using: String.Encoding.utf8, allowLossyConversion: false){
                    let linkData = JSON(data: data)
                    if let urlString = linkData["target_url"].string,
                        let fbUrl = URL(string: urlString){
                        
                        if urlString.range(of: "get.judge-it.net") == nil {
                            Alamofire.request(fbUrl, method: .head).response{ response in
                                if let resolvedUrl = response.response?.url {
                                    self.joinQuestion(resolvedUrl)
                                }
                            }
                            
                        } else {
                            joinQuestion(fbUrl)
                        }
                    }
                }
                
            } else if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                let rawQuestionId = IDObfuscator.deObfuscate(components.queryItems?.filter({$0.name == "ref"}).first?.value) {
                showQuestion("questions/\(rawQuestionId)", inTab: VotingViewController.TabTag.voting)
                return true
            }
        }
        return false
    }
    
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        if let url = userActivity.webpageURL, userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            print(url)
            if url.host == "get.judge-it.net" && url.path == "/broadcast" {
                joinQuestion(url)
                return true
            }
        }
        return false
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return FBSDKApplicationDelegate.sharedInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation) ||
            GIDSignIn.sharedInstance().handle(url, sourceApplication: sourceApplication,annotation: annotation) ||
            self.application(application, handleOpen: url)
    }
    
    @available(iOS 9.0, *)
    func application(_ application: UIApplication,
                     open url: URL, options: [UIApplicationOpenURLOptionsKey: Any]) -> Bool {
        let sourceApplication = options[UIApplicationOpenURLOptionsKey.sourceApplication] as! String
        let annotation = options[UIApplicationOpenURLOptionsKey.annotation]
        
        return FBSDKApplicationDelegate.sharedInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)
            || GIDSignIn.sharedInstance().handle(url, sourceApplication: sourceApplication,annotation: annotation)
            || self.application(application, handleOpen: url)
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        var bgTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "BagdeUpdate") {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = UIBackgroundTaskInvalid
        }
        
        self.fetchBadgeCount({ (badgeCount, error) in
            if let badgeCount = badgeCount {
                UIApplication.shared.applicationIconBadgeNumber = badgeCount
            }
            
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = UIBackgroundTaskInvalid
        })
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        
        fetchBadgeCount({count, error in
            if let count = count, count > 0 {
                NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: self, userInfo: nil)
            }
        })
        
        // Dismiss all current notifications
        UIApplication.shared.cancelAllLocalNotifications()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        FBSDKAppEvents.activateApp()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    }
    
    static func isLoggedIn() -> Bool {
        let userDefaults = UserDefaults.standard
        
        let token = userDefaults.secretObject(forKey: "current_login_token")
        let userId = userDefaults.object(forKey: "current_user_id")
        
        return token != nil && userId != nil
    }
    
    static func noteApplicationIsReadyForNotifications(_ tabBarController: JITabBarController) {
        rootTabBarController = tabBarController
        if let userInfo = notificationUserInfoToUseAfterLogin {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.handleNotification(userInfo)
            }
        }
    }
    
    func fetchBadgeCount(_ completion: @escaping (Int?, Error?) -> Void) {
        var parameters = [String : Any]()
        parameters["user-id"] = GlobalQuestionData.user_id
        parameters["token"] = GlobalQuestionData.login_token
        
        Communicator.uncachedManager.request(Communicator.instance.SERVER_URL + "/api/v2/unseen/all", method: .get, parameters: parameters, encoding: URLEncoding.queryString, headers: ["Accept": "application/json", "If-None-Match": "nuthin"]).responseJSON(completionHandler: { response in
            if let error = response.result.error {
                completion(nil, error)
            } else {
                if let resultDict = response.result.value as? [String : Any],
                    let bagdeCount = resultDict["badge"] as? Int {
                    completion(bagdeCount, nil)
                } else {
                    completion(nil, nil)
                }
            }
        })
    }
    
}
