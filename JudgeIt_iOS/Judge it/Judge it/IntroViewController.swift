//
//  IntroViewController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 30/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation

class IntroViewController : UIViewController{
    
    @IBOutlet var getStartedView: UIView!
    
    @IBOutlet var introIcon: UIImageView!
    
    @IBOutlet var introLabel: UILabel!
    
    fileprivate var introIndex = 0
    fileprivate var introImage:UIImage?
    fileprivate var introText:String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        UserDefaults().set(self.title, forKey: "selectedClass")
//        UserDefaults().synchronize()
        getStartedView.layer.cornerRadius = getStartedView.frame.height/2
        
        introLabel.text = introText
        introIcon.image = introImage
    }
    
    func passIndex(_ index:Int){
        introIndex = index
        switch(index){
        case 0:
            introImage = UIImage(imageLiteralResourceName: "intro_icon1")
            introText = NSLocalizedString("intro_text1", comment: "")
        case 1:
            introImage = UIImage(imageLiteralResourceName: "intro_icon2")
            introText = NSLocalizedString("intro_text2", comment: "")
        case 2:
            introImage = UIImage(imageLiteralResourceName: "intro_icon3")
            introText = NSLocalizedString("intro_text3", comment: "")
        case 3:
            introImage = UIImage(imageLiteralResourceName: "intro_icon4")
            introText = NSLocalizedString("intro_text4", comment: "")
        default:
            break
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "Intro")
        tracker?.send((GAIDictionaryBuilder.createScreenView().build() as NSDictionary) as! [AnyHashable: Any])
        
        getStartedView.isHidden = introIndex < 3
    }
    
    
    @IBAction func skipPressed(_ sender: AnyObject) {
        let prefs = UserDefaults.standard
        prefs.set(false, forKey: "login_first_time")
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func getStartedPressed(_ sender: AnyObject) {
        let prefs = UserDefaults.standard
        prefs.set(false, forKey: "login_first_time")
        self.dismiss(animated: true, completion: nil)
    }
    
}
