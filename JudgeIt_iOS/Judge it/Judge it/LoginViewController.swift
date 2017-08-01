//
//  LoginViewController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 14/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import UIKit
import Adjust
import SwiftyJSON
import IQKeyboardManagerSwift

class LoginViewController : UIViewController, UITextFieldDelegate, FBSDKLoginButtonDelegate, GIDSignInDelegate, GIDSignInUIDelegate{
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet var forgotPasswordButton: UIButton!
    
    @IBOutlet var emailLoginView: UIView!
    
    @IBOutlet var fbLoginButton: FBSDKLoginButton!
    @IBOutlet weak var googleLoginButton: UIButton!
    @IBOutlet var emailLoginButton: UIButton!
    
    @IBOutlet weak var socialMediaLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    
    @IBOutlet var progressView: UIView!
    
    var isNewRegistration = false
    
    
    func handleLoginError(_ error: NSError) {
        let response_code = error.code;
        
        if response_code == ResponseCode.VERSION_MISMATCH.rawValue {
            let alert = UIAlertView()
            alert.title = NSLocalizedString("error_version_mismatch_title", comment: "")
            alert.message = NSLocalizedString("error_version_mismatch", comment: "")
            alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK"))
            alert.show()
            
            GlobalQuestionData.fbToken = nil
            FBSDKLoginManager().logOut()
            GlobalQuestionData.googleToken = nil
            GIDSignIn.sharedInstance().signOut()
        } else if response_code == ResponseCode.NO_ACCOUNT.rawValue {
            let alert = UIAlertView()
            alert.title = NSLocalizedString("error_no_account_title", comment: "")
            alert.message = NSLocalizedString("error_no_account", comment: "")
            alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK"))
            alert.show()
            
            GlobalQuestionData.fbToken = nil
            FBSDKLoginManager().logOut()
            GlobalQuestionData.googleToken = nil
            GIDSignIn.sharedInstance().signOut()
        } else if response_code == ResponseCode.WRONG_PASSWORD.rawValue {
            let alert = UIAlertView()
            alert.title = NSLocalizedString("error_incorrect_password", comment: "")
            alert.message = NSLocalizedString("error_incorrect_password_text", comment: "")
            alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK"))
            alert.show()
            
            GlobalQuestionData.fbToken = nil
            FBSDKLoginManager().logOut()
            GlobalQuestionData.googleToken = nil
            GIDSignIn.sharedInstance().signOut()
        } else {
            // Generic error handling:
            GlobalQuestionData.fbToken = nil
            FBSDKLoginManager().logOut()
            GlobalQuestionData.googleToken = nil
            GIDSignIn.sharedInstance().signOut()
            
            let alert = UIAlertView()
            alert.title = ""
            alert.message = NSLocalizedString("error_server_down", comment: "")
            alert.message = alert.message!+" ("+error.localizedDescription+")"
            alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK"))
            alert.show()
        }
    }
    
    func doLogin(_ email: String?, password: String, externalAccount: LoginTask.ExternalAccount?, externalUser: String?) {
        progressView.isHidden = false
        
        self.isNewRegistration = false
        LoginTask.loginTask(email, password: password, externalAccount: externalAccount, externalUser: externalUser, completion: { (JSON, error) in
            self.progressView.isHidden = true
            
            if (error != nil) {
                self.handleLoginError(error!)
                return;
            }
            
            if let response=JSON {
                if let response_code = response["response_code"].int{
                    if response_code == ResponseCode.OK.rawValue {
                        let user_id = response["user_id"].int
                        let login_token = response["login_token"].string
                        if user_id != nil && login_token != nil {
                            GlobalQuestionData.user_id = user_id!
                            GlobalQuestionData.login_token = login_token!
                            GlobalQuestionData.afterLogout = false
                            GlobalQuestionData.phoneIsSet = response["phone_number"].string != nil
                            let prefs = UserDefaults.standard
                            GlobalQuestionData.phoneNumber = prefs.secretObject(forKey: "phone_number") as? String
                            
                            if(self.email != nil && self.email!.length > 0 && self.password != nil && self.password!.length > 0){
                                let prefs = UserDefaults.standard
                                prefs.set( self.email, forKey: "pref_user")
                                prefs.setSecretObject(self.password, forKey: "pref_pass")
                                
                                GlobalQuestionData.email = self.email
                                
                                //Track: Email login
                                Adjust.trackEvent(ADJEvent(eventToken: "5ghlk5"))
                                
                                GlobalQuestionData.fbToken = nil
                                FBSDKLoginManager().logOut()
                                GlobalQuestionData.googleToken = nil
                                GIDSignIn.sharedInstance().signOut()
                            } else if(FBSDKAccessToken.current() != nil){
                                GlobalQuestionData.googleToken = nil
                                GIDSignIn.sharedInstance().signOut()
                                
                                //Track: Facebook login
                                Adjust.trackEvent(ADJEvent(eventToken: "wkzxlg"))
                                
                                let prefs = UserDefaults.standard
                                //prefs.removeObjectForKey("pref_user")
                                prefs.setSecretObject(nil, forKey: "pref_pass")
                            } else if(GIDSignIn.sharedInstance().currentUser != nil){
                                GlobalQuestionData.fbToken = nil
                                FBSDKLoginManager().logOut()
                                
                                // Track: Google Login
                                Adjust.trackEvent(ADJEvent(eventToken: "2uk0ye"))
                                
                                let prefs = UserDefaults.standard
                                //prefs.removeObjectForKey("pref_user")
                                prefs.setSecretObject(nil, forKey: "pref_pass")
                            }
                            
                            if(AppDelegate.registrationToken != nil){
                                GCMRegisterTask.gcmRegisterTask(AppDelegate.registrationToken!, delegate: RegistrationDelegate())
                            }
                            
                            prefs.setSecretObject(GlobalQuestionData.login_token, forKey: "current_login_token")
                            prefs.set(GlobalQuestionData.user_id, forKey: "current_user_id")
                            
                            self.performSegue(withIdentifier: "home", sender: self)
                        }
                    }
                }
            }
        })
    }
    
    
    func finish() {
        self.performSegue(withIdentifier: "home", sender: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // TODO: app start handling needs to be improved
        // This is only a step into
        if AppDelegate.isLoggedIn() {
            self.performSegue(withIdentifier: "home", sender: self)
            return
        }
        
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        let prefs = UserDefaults.standard
        
        self.navigationController?.isNavigationBarHidden = true
        self.navigationController?.navigationBar.barTintColor = UIColor.judgeItPrimaryColor
        self.navigationController?.navigationBar.tintColor = UIColor.white
        
        emailTextField.text = prefs.string(forKey: "pref_user")
        emailLoginButton.layer.cornerRadius = 8
        
      //  forgotPasswordButton.titleLabel?.numberOfLines = 1
      //  forgotPasswordButton.titleLabel?.adjustsFontSizeToFitWidth = true
      //  forgotPasswordButton.titleLabel?.lineBreakMode = NSLineBreakMode.byClipping
        
        fbLoginButton.setTitle(nil, for: UIControlState())
        let fbImage = UIImage(imageLiteralResourceName: "ic_facebook")
        fbLoginButton.setBackgroundImage(fbImage.withRenderingMode(.alwaysTemplate), for: UIControlState.normal)
        fbLoginButton.setBackgroundImage(nil, for: UIControlState.selected)
        fbLoginButton.setBackgroundImage(nil, for: UIControlState.highlighted)
        fbLoginButton.setImage(nil, for: UIControlState())
        fbLoginButton.sizeToFit()
        fbLoginButton.layer.cornerRadius = 42
        
        let googleImage = UIImage(imageLiteralResourceName: "ic_googleplus")
        googleLoginButton.setBackgroundImage(googleImage.withRenderingMode(.alwaysTemplate), for: .normal)
        googleLoginButton.layer.cornerRadius = 42
        
        fbLoginButton.readPermissions = ["public_profile", "user_friends"]
        fbLoginButton.delegate = self
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        
        if !GlobalQuestionData.afterLogout {
            
            if let pref_mail = prefs.object(forKey: "pref_user") as? String{
                if let pref_pass = prefs.secretObject(forKey: "pref_pass") as? String{
                    self.doLogin(pref_mail, password: pref_pass, externalAccount: nil, externalUser: nil)
                }
            }
            
            if let fbToken = FBSDKAccessToken.current() {
                doFacebookLogin(fbToken)
            } else if let googleToken = GIDSignIn.sharedInstance().currentUser {
                doGoogleLogin(googleToken)
            } else{
                GIDSignIn.sharedInstance().signInSilently()
            }
        }
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.keyboardWillShow(_:)), name:NSNotification.Name.UIKeyboardWillShow, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.keyboardWillHide(_:)), name:NSNotification.Name.UIKeyboardWillHide, object: nil);
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        IQKeyboardManager.sharedManager().enable = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        IQKeyboardManager.sharedManager().enable = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.isNavigationBarHidden = true
        
        let prefs = UserDefaults.standard
        let showIntro = prefs.object(forKey: "login_first_time") as? Bool ?? true
        if(showIntro){
            //            showHelpOverlay()
        }
        super.viewDidAppear(animated)
        
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "Login")
        tracker?.send((GAIDictionaryBuilder.createScreenView().build() as NSDictionary) as! [AnyHashable: Any])
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (textField === emailTextField){
            let prefs = UserDefaults.standard
            prefs.set(emailTextField.text, forKey: "pref_user")
            passwordTextField.becomeFirstResponder()
            return true
        } else if (textField === passwordTextField){
            loginTouchEvent(passwordTextField)
            return true
        }
        return false
    }
    
    var keyboardShown = false
    func keyboardWillShow(_ sender: Notification) {
        if(!keyboardShown){
            if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad){
                self.view.frame.origin.y -= 300
            }else{
                self.view.frame.origin.y -= 195
            }
        }
        keyboardShown = true
    }
    
    func keyboardWillHide(_ sender: Notification) {
        if(keyboardShown){
            if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad){
                self.view.frame.origin.y += 300
            }else{
                self.view.frame.origin.y += 195
            }
        }
        keyboardShown = false
    }
    
    func dismissKeyboard(){
        view.endEditing(true)
    }
    
    @IBAction func gotoEmailLogin(_ sender: UIButton) {
        self.googleLoginButton.isHidden = true
        self.fbLoginButton.isHidden = true
        self.emailLoginButton.isHidden = true
        self.socialMediaLabel.isHidden = true
        self.emailLabel.isHidden = true
        UIView.transition(with: emailLoginView, duration: 0.5, options: UIViewAnimationOptions.transitionCrossDissolve, animations: {
            self.emailLoginView.isHidden = false
        }, completion: nil)
    }
    
    
    @IBAction func leaveEmailLogin(_ sender: UIButton) {
        UIView.transition(with: emailLoginView, duration: 0.5, options: UIViewAnimationOptions.transitionCrossDissolve, animations: {
            self.emailLoginView.isHidden = true
        }, completion: { _ in
            self.googleLoginButton.isHidden = false
            self.fbLoginButton.isHidden = false
            self.emailLoginButton.isHidden = false
            self.emailLabel.isHidden = false
            self.socialMediaLabel.isHidden = false
        })
    }
    
    func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWith result: FBSDKLoginManagerLoginResult!, error: Error!) {
        if ((error) != nil) {
            // Process error
            print(error.localizedDescription)
        } else if result.isCancelled {
            // Handle cancellations
        } else {
            doFacebookLogin(result.token)
        }
    }
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        GlobalQuestionData.afterLogout = true
        GlobalQuestionData.fbToken = nil
    }
    
    func doFacebookLogin(_ token: FBSDKAccessToken){
        let prefs = UserDefaults.standard
        let isRegistered = prefs.object(forKey: "\(LoginTask.ExternalAccount.facebook.rawValue)_\(token.userID)") as? Bool ?? false
        
        if !isRegistered {
            let eulaNavigator = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EulaNavigation") as! UINavigationController
            let eulaController = eulaNavigator.viewControllers.first as! EulaConfirmController
            eulaController.hasConfirmedCallback = {
                GlobalQuestionData.fbToken = token
                
                prefs.set(true, forKey: "\(LoginTask.ExternalAccount.facebook.rawValue)_\(token.userID)")
                
                GlobalQuestionData.email = nil
                self.isNewRegistration = true
                self.doLogin(nil, password: token.tokenString, externalAccount: .facebook, externalUser: token.userID)
            }
            eulaController.hasCancelledCallback = {
                FBSDKLoginManager().logOut()
            }
            
            progressView.isHidden = false
            self.present(eulaNavigator, animated: true, completion: nil);
        } else{
            GlobalQuestionData.fbToken = token
            
            progressView.isHidden = false
            
            GlobalQuestionData.email = nil
            self.isNewRegistration = false
            self.doLogin(nil, password: token.tokenString, externalAccount: .facebook, externalUser: token.userID)
        }
        
    }
    
    @IBAction func googleButtonPressed(_ sender: Any) {
        GIDSignIn.sharedInstance().signIn()
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        //        print("test")
        if let err = error {
            print(err)
        }
        else {
            doGoogleLogin(user)
        }
    }
    
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        GlobalQuestionData.afterLogout = true
        GlobalQuestionData.googleToken = nil
    }
    
    func doGoogleLogin(_ user: GIDGoogleUser){
        let prefs = UserDefaults.standard
        let isRegistered = prefs.object(forKey: "\(LoginTask.ExternalAccount.google.rawValue)_\(user.userID)") as? Bool ?? false
        
        if(!isRegistered){
            let eulaNavigator = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EulaNavigation") as! UINavigationController
            let eulaController = eulaNavigator.viewControllers.first as! EulaConfirmController
            eulaController.hasConfirmedCallback = {
                GlobalQuestionData.googleToken = user
                
                prefs.set(true, forKey: "\(LoginTask.ExternalAccount.google.rawValue)_\(user.userID)")
                
                GlobalQuestionData.email = nil
                self.isNewRegistration = true
                self.doLogin(nil, password: user.authentication.idToken, externalAccount: .google, externalUser: user.userID)
            }
            eulaController.hasCancelledCallback = {
                GIDSignIn.sharedInstance().signOut()
            }
            
            progressView.isHidden = false
            
            self.present(eulaNavigator, animated: true, completion: nil)
            self.navigationController?.isNavigationBarHidden = false
        } else{
            GlobalQuestionData.googleToken = user
            
            progressView.isHidden = false
            
            GlobalQuestionData.email = nil
            self.isNewRegistration = false
            self.doLogin(nil, password: user.authentication.idToken, externalAccount: .google, externalUser: user.userID)
        }
    }
    
    var email:String!
    var password:String!
    
    @IBAction func loginTouchEvent(_ sender: AnyObject) {
        
        email = emailTextField.text
        password = passwordTextField.text
        dismissKeyboard()
        
        if(isEmailValid(email)){
            progressView.isHidden = false
            self.isNewRegistration = false
            self.doLogin(self.email, password: self.password, externalAccount: nil, externalUser: nil)
        } else{
            let alert = UIAlertView()
            alert.title = NSLocalizedString("error_invalid_password_title", comment: "")
            alert.message = NSLocalizedString("error_invalid_password", comment: "")
            alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK"))
            alert.show()
        }
        
    }
    
    @IBAction func registerTouchEvent(_ sender: AnyObject) {
        email = emailTextField.text
        password = passwordTextField.text
        dismissKeyboard()
        
        if(isEmailValid(email) && isPasswordValid(password)){
            let eulaNavigator = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "EulaNavigation") as! UINavigationController
            let eulaController = eulaNavigator.viewControllers.first as! EulaConfirmController
            eulaController.hasConfirmedCallback = {
                
                self.progressView.isHidden = false
                
                RegisterTask.registerTask(self.email, password: self.password, completion: { (JSON, error) in
                    
                    self.progressView.isHidden = true
                    
                    if (error != nil) {
                        // Registration failed:
                        
                        GlobalQuestionData.fbToken = nil
                        FBSDKLoginManager().logOut()
                        GlobalQuestionData.googleToken = nil
                        GIDSignIn.sharedInstance().signOut()
                        
                        let alert = UIAlertView()
                        alert.title = ""
                        alert.message = NSLocalizedString("error_server_down", comment: "") + "("+error!.localizedDescription+")"
                        alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK"))
                        alert.show()
                    } else if let response = JSON {
                        // Registration success:
                        if let response_code = response["response_code"].int {
                            if(response_code == ResponseCode.OK.rawValue){
                                let user_id = response["user_id"].int
                                let login_token = response["login_token"].string
                                if(user_id != nil && login_token != nil){
                                    GlobalQuestionData.user_id = user_id!
                                    GlobalQuestionData.login_token = login_token!
                                    GlobalQuestionData.afterLogout = false
                                    
                                    if self.email.length > 0 && self.password.length > 0 {
                                        let prefs = UserDefaults.standard
                                        prefs.set( self.email, forKey: "pref_user")
                                        prefs.setSecretObject( self.password, forKey: "pref_pass")
                                        
                                        GlobalQuestionData.email = self.email
                                        
                                        GlobalQuestionData.fbToken = nil
                                        FBSDKLoginManager().logOut()
                                        GlobalQuestionData.googleToken = nil
                                        GIDSignIn.sharedInstance().signOut()
                                    }
                                    
                                    DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.high).async(execute: {
                                        if(AppDelegate.registrationToken != nil){
                                            GCMRegisterTask.gcmRegisterTask(AppDelegate.registrationToken!, delegate: RegistrationDelegate())
                                        }
                                    })
                                    
                                    let prefs = UserDefaults.standard
                                    prefs.setSecretObject(GlobalQuestionData.login_token, forKey: "current_login_token")
                                    prefs.set(GlobalQuestionData.user_id, forKey: "current_user_id")
                                    self.isNewRegistration = true
                                    self.performSegue(withIdentifier: "home", sender: self)
                                }
                            } else if response_code == ResponseCode.VERSION_MISMATCH.rawValue {
                                let alert = UIAlertView()
                                alert.title = NSLocalizedString("error_version_mismatch_title", comment: "")
                                alert.message = NSLocalizedString("error_version_mismatch", comment: "")
                                alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK"))
                                alert.show()
                            } else if response_code == ResponseCode.FAIL.rawValue || response_code == ResponseCode.ACCOUNT_EXISTS.rawValue {
                                let alert = UIAlertView()
                                alert.title = NSLocalizedString("error_registration_title", comment: "")
                                alert.message = NSLocalizedString("error_registration", comment: "")
                                alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK"))
                                alert.show()
                            }
                        }
                    }
                })
            }
            
            
            self.present(eulaNavigator, animated: true, completion: nil)
            
        } else {
            let alert = UIAlertView()
            alert.title = NSLocalizedString("error_invalid_password_title", comment: "")
            alert.message = NSLocalizedString("error_invalid_password", comment: "")
            alert.addButton(withTitle: NSLocalizedString("ok", comment: "OK"))
            alert.show()
        }
    }
    
    @IBAction func passwordForgottenEvent(_ sender: AnyObject) {
        
        let alert = UIAlertController(title: NSLocalizedString("passwordreset_title", comment:""), message: NSLocalizedString("pw_reset_info", comment: ""), preferredStyle: UIAlertControllerStyle.alert)
        alert.addTextField(configurationHandler: {textField in
            textField.placeholder = NSLocalizedString("prompt_email", comment: "")
            textField.text = UserDefaults.standard.string(forKey: "pref_user")
            textField.clearButtonMode = .whileEditing
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel",comment:""), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .default, handler: { alertAction in
            
            if let email = alert.textFields?.first?.text{
                DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
                    let request:[String:Any] = [
                        "version": Communicator.SERVER_VERSION,
                        "request_type": RequestType.PASSWORD_RESET.rawValue,
                        "debug": false,
                        "email": email
                    ]
                    
                    Communicator.instance.communicateWithServer(request, callback: {_,_ in }, delegate: TaskDelegate<Bool>())
                })
                
            }
        }))
        present(alert, animated: true, completion: nil)
        
    }
    
    fileprivate func isEmailValid(_ email:String) -> Bool {
        return email.range(of: "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Za-z]{2,4}$", options: .regularExpression) != nil
    }
    fileprivate func isPasswordValid(_ password:String) -> Bool {
        return password.length >= 6 && !password.contains(" ")
    }
    
    @IBAction func helpPressed(_ sender: AnyObject) {
        showHelpOverlay()
    }
    
    func showHelpOverlay(){
        let introController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "IntroPageController")
        introController.modalPresentationStyle = .fullScreen
        introController.modalTransitionStyle = .coverVertical
        self.present(introController, animated: true, completion: {})
    }
    
    
    class RegistrationDelegate : GCMRegisterTask.GCMTaskDelegate{
        override func onPostExecute(_ result: Bool) {
            if(!result){
                print("Sending gcm token to backend failed!")
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "home"    {
            if self.isNewRegistration {
                let tabBarController = segue.destination as! JITabBarController
                tabBarController.initialTabIndex = JITabBarController.TabTag.settings.rawValue
                tabBarController.isNewRegistration = true
            }
        }
    }
    
    @IBAction func unwindFromLogout(_ sender: UIStoryboardSegue) {
    }
}
