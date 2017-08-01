//
//  EulaConfirmController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 01/02/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation

class EulaConfirmController : UIViewController, UITextViewDelegate{
    
    @IBOutlet var eulaTextField: UITextView!
    @IBOutlet var okButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.localizeStrings()
    }
    
    @IBAction func confirmAction(_ sender: AnyObject) {
        self.presentingViewController?.dismiss(animated: true, completion: nil);
        self.hasConfirmedCallback!()
    }
    
    @IBAction func cancelAction(_ sender: AnyObject) {
        self.presentingViewController?.dismiss(animated: true, completion: nil);
        self.hasCancelledCallback?()
    }
    
    var hasConfirmedCallback:(()->())? = nil
    var hasCancelledCallback:(()->())? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        UserDefaults().set(self.title, forKey: "selectedClass")
//        UserDefaults().synchronize()
        okButton.layer.cornerRadius = 5
        cancelButton.layer.cornerRadius = 5
        
        let htmlString = NSLocalizedString("eula_content", comment: "")
        let splitString = htmlString.components(separatedBy: CharacterSet(charactersIn: "[]"))
        let attributedString = NSMutableAttributedString(string: splitString.reduce("", {return $0 + $1}),
                                                         attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 16)])
        
        let eulaRange = (attributedString.string as NSString).range(of: splitString[1])
        let privacyRange = (attributedString.string as NSString).range(of: splitString[3])
        print("\(eulaRange.location) + \(eulaRange.length)")
        print("\(privacyRange.location) + \(privacyRange.length)")
        attributedString.addAttribute(NSLinkAttributeName, value: "eula.html", range: eulaRange)
        attributedString.addAttribute(NSLinkAttributeName, value: "privacy.html", range: privacyRange)
        
        let linkAttributes:[String:Any] = [NSForegroundColorAttributeName: UIColor.blue,
                                           NSUnderlineColorAttributeName: UIColor.lightGray]
        eulaTextField.linkTextAttributes = linkAttributes
        
        eulaTextField.attributedText = attributedString
        eulaTextField.delegate = self
        eulaTextField.layer.cornerRadius = 5
        eulaTextField.dataDetectorTypes = UIDataDetectorTypes.link
        
        let topOffset = CGFloat(20)/*max((eulaTextField.bounds.size.height)/2.0, 0)*/
        print("offset \(topOffset)")
        eulaTextField.contentOffset = CGPoint(x: 0, y: topOffset)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let topOffset = (eulaTextField.frame.size.height - eulaTextField.contentSize.height)/2.0
        print("offset \(topOffset)")
        eulaTextField.contentOffset = CGPoint(x: 0, y: topOffset)
        
        super.viewDidAppear(animated)
        
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "Eula")
        tracker?.send(GAIDictionaryBuilder.createScreenView().build() as NSDictionary? as! [AnyHashable: Any])
    }
    
    @available(iOS 10.0, *)
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.relativeString == "eula.html" {
            let url = Bundle.main.url(forResource: "eula", withExtension:"html")
            
            let webViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "WebViewController") as! LicenseViewController
            webViewController.url = url
            
            self.navigationController?.pushViewController(webViewController, animated: true)
            self.navigationController?.isNavigationBarHidden = false
        } else if URL.relativeString == "privacy.html" {
            let url = Bundle.main.url(forResource: "privacy", withExtension:"html")
            
            let webViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "WebViewController") as! LicenseViewController
            webViewController.url = url
            
            self.navigationController?.pushViewController(webViewController, animated: true)
            self.navigationController?.isNavigationBarHidden = false
        }
        
        
        return false
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool{
        if URL.relativeString == "eula.html" {
            let url = Bundle.main.url(forResource: "eula", withExtension:"html")
            
            let webViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "WebViewController") as! LicenseViewController
            webViewController.url = url
            
            self.navigationController?.pushViewController(webViewController, animated: true)
            self.navigationController?.isNavigationBarHidden = false
        } else if URL.relativeString == "privacy.html" {
            let url = Bundle.main.url(forResource: "privacy", withExtension:"html")
            
            let webViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "WebViewController") as! LicenseViewController
            webViewController.url = url
            
            self.navigationController?.pushViewController(webViewController, animated: true)
            self.navigationController?.isNavigationBarHidden = false
        }
        
        
        return false
    }
    
    func textViewDidChangeSelection(_ textView: UITextView){
        if(NSEqualRanges(textView.selectedRange, NSMakeRange(0, 0)) == false) {
            textView.selectedRange = NSMakeRange(0, 0);
        }
    }
    
}
