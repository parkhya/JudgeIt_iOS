//
//  JITabBarController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 06/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation

class JITabBarController : UITabBarController, UITabBarControllerDelegate {
    
    var initialTabIndex: Int?
    var isNewRegistration = false
    
    enum TabTag: Int {
        case private_questions = 0
        case public_questions = 1
        case chats = 2
        case contacts = 3
        case settings = 4
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        self.tabBar.tintColor = UIColor.judgeItPrimaryColor
        
        self.tabBar.setNeedsLayout()
        self.tabBar.setNeedsDisplay()
        self.selectedIndex = 0
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateTabBadges), name: NSNotification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
    }
 
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let initialTabIndex = initialTabIndex {
            self.selectedIndex = initialTabIndex
            self.initialTabIndex = nil // do it only once
        }

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if isNewRegistration {
            let profileController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "home") as! ProfileViewController
            (self.selectedViewController as? UINavigationController)?.pushViewController(profileController, animated: true)
            isNewRegistration = false
        }
        
        // TODO: remove this hack after migration to new login workflow:
        AppDelegate.noteApplicationIsReadyForNotifications(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateTabBadges(){
        Question.fetchQuestions(questionId: nil, alsoCached: true) { (questions, error) in
            if let questions = questions {
                let (chatBadge, questionBadge) = self.sumBadgeCount(questions: questions)
                
                self.tabBar.items![0].badgeValue = questionBadge > 0 ? "\(questionBadge)" : nil
                self.tabBar.items![2].badgeValue = chatBadge > 0 ? "\(chatBadge)" : nil
            }
        }
    }
    
    func sumBadgeCount(questions: [Question]) -> (Int, Int) {
        var chatBadgeCount = 0
        var questionBadgeCount = 0
        for question in questions {
            if question.isChatOnly {
                if question.isUnseen {
                    chatBadgeCount += 1
                } else {
                    chatBadgeCount += question.unseenCountTotal()
                }
            } else {
                if question.isUnseen {
                    questionBadgeCount += 1
                } else {
                    questionBadgeCount += question.unseenCountTotal()
                }
            }
        }
        return (chatBadgeCount, questionBadgeCount)
    }
    
    /*
     * Prevent from switching away from ProfileViewController, if no phone number set. Once.
     */
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        
        // Prevent popping back the top navigation controller of the current tab:
        if self.selectedViewController === viewController {
            return false
        }
        
        // Stuff for ProfileViewController:
        if let sourceViewController = self.selectedViewController as? UINavigationController {
            if let profileViewController = sourceViewController.topViewController as? ProfileViewController {
                
                if profileViewController.profileUser?.phoneNumberHash == nil && !UserDefaults.standard.bool(forKey: "AskedForPhoneNumber") {
                    
                    let phoneAlertController = UIAlertController(title: nil, message: NSLocalizedString("[Phone Number Missing Alert Message]", comment: ""), preferredStyle: .alert)
                    phoneAlertController.addAction(UIAlertAction(title: NSLocalizedString("Back", comment: ""), style: .default, handler: { (action) in
                        // Make phone field first responder here?
                        profileViewController.phoneField.becomeFirstResponder()
                    }))
                    phoneAlertController.addAction(UIAlertAction(title: NSLocalizedString("Next", comment: ""), style: .default, handler: { (action) in
                        UserDefaults.standard.set(true, forKey: "AskedForPhoneNumber")
                        self.selectedViewController = viewController // Switch to the viewController the user wanted, originally
                    }))

                    self.present(phoneAlertController, animated: true, completion: nil)
                    
                    return false
                }
                return true
            }
        }
        return true
    }
}
