//
//  SettingsViewController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 10/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation
import Adjust

class SettingsViewController : UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    lazy var imagePicker = UIImagePickerController()
    var wallpaperView:UIImageView?
    
    @IBOutlet weak var allowNotificationsSwitch: UISwitch!
//    @IBOutlet weak var privacyModeSwitch: UISwitch!
    
//    @IBOutlet weak var privacyModeTitle: UILabel!
//    @IBOutlet weak var privacyModeText: UILabel!
    
    var profileUser: User?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.localizeStrings()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // avoid trailing separators:
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        self.tableView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0)
        imagePicker.delegate = self
        
        let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 1))
        wallpaperView = cell?.viewWithTag(101) as? UIImageView
        let prefs = UserDefaults.standard
        if let path = prefs.object(forKey: "wallpaper_path") as? String{
            if let dir : NSString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first as NSString?{
                let relativePath = dir.appendingPathComponent(path)
                if let image = UIImage.init(contentsOfFile: relativePath){
                    wallpaperView?.image = image
                }
            }
        } else if let color = prefs.colorForKey("wallpaper_color"){
            wallpaperView?.backgroundColor = color
        }
        
        self.allowNotificationsSwitch.onTintColor = UIColor.judgeItPrimaryColor
//        self.privacyModeSwitch.onTintColor = UIColor.judgeItPrimaryColor
       
//        self.privacyModeTitle.text = NSLocalizedString("privacymode_title", comment: "")
//        self.privacyModeText.text = NSLocalizedString("privacymode_text", comment: "")
        
        self.reload(forced: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.reload()
    }
    
    func reload(forced: Bool = false) {
        User.fetchProfile(alsoCached: !forced) { (profileUser, error) in
            if let profileUser = profileUser {
                self.profileUser = profileUser
                self.allowNotificationsSwitch.isOn = profileUser.allNotificationsMuted ? false : true
//                self.privacyModeSwitch.isOn = profileUser.privacyMode
            }
        }
    }
    
    @IBAction func toggleNotificationsEnabled(_ switchControl: UISwitch) {
        User.patchProfile(allNotificationsMuted: !switchControl.isOn) { (error) in
            self.reload(forced: true)
        }
    }
    
    var cancelableBlockPrivacyMode: dispatch_cancelable_block_t?
    
    @IBAction func togglePrivacyMode(_ sender: UISwitch) {
        let privacyMode = sender.isOn
        cancel_block(cancelableBlockPrivacyMode)
        cancelableBlockPrivacyMode = dispatch_after_delay(1.5) {
            User.patchProfile(privacyMode: privacyMode) { (error) in
                if error != nil {
                    self.reload(forced: true)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.selectionStyle = .none
        
        if(indexPath.section == 1){
            if wallpaperView == nil{
                wallpaperView = (cell.viewWithTag(101) as! UIImageView)
            }
            
            let prefs = UserDefaults.standard
            if let path = prefs.object(forKey: "wallpaper_path") as? String, wallpaperView!.image == nil{
                if let dir : NSString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first as NSString?{
                    let relativePath = dir.appendingPathComponent(path)
                    if let image = UIImage.init(contentsOfFile: relativePath){
                        wallpaperView!.image = image
                    }
                }
            } else if let color = prefs.colorForKey("wallpaper_color"){
                wallpaperView!.backgroundColor = color
            }
        }
    }
    
    func openURL(_ url: URL?) {
        if (url == nil) {
            return;
        }
        let webViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "WebViewController") as! LicenseViewController
        webViewController.url = url
        //webViewController.title = NSLocalizedString("Info", comment: "WebView Title");
        
        self.navigationController?.pushViewController(webViewController, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        print("section = \(section)")
        switch section {
        case 0:
                return makeTableViewHeaderView(title: NSLocalizedString("SProfile", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "AmaticSC-Regular")
        case 1:
            return makeTableViewHeaderView(title: NSLocalizedString("SDisplay", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "")
        case 2:
            return makeTableViewHeaderView(title: NSLocalizedString("SNotifications", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "")
        case 3:
           return makeTableViewHeaderView(title: NSLocalizedString("SGeneral", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "")
        case 4:
           return makeTableViewHeaderView(title: NSLocalizedString("SLegal", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "")
        default:
            return makeTableViewHeaderView(title: NSLocalizedString("SProfile", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "AmaticSC-Regular")

        }
        return makeTableViewHeaderView(title: NSLocalizedString("SProfile", comment: ""), width: self.tableView.bounds.size.width, fontFamilyName: "AmaticSC-Regular")
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = self.tableView(tableView, cellForRowAt: indexPath)
        //        NSLog("cell = %@", cell);
        //let reuseId:NSString? = cell.reuseIdentifier
        
        //NSLog("tag = %@", reuseId ?: "")
        if (indexPath.section == 1){
            if wallpaperView == nil{
                wallpaperView = cell.viewWithTag(101) as? UIImageView
            }
            
            let alert = UIAlertController(title: NSLocalizedString("chat_background", comment:""), message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
            
            let prefs = UserDefaults.standard
            alert.addAction(UIAlertAction(title: NSLocalizedString("select_wallpaper", comment: ""), style: .default){ alertAction in
                self.imagePicker.allowsEditing = false
                self.imagePicker.sourceType = .photoLibrary
                
                self.present(self.imagePicker, animated: true, completion: nil)
                })
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("color_white", comment: ""), style: .default){ alertAction in
                prefs.set(nil, forKey: "wallpaper_path")
                self.wallpaperView?.image = nil
                
                let color = UIColor(redInt: 0xFF,greenInt: 0xFF,blueInt: 0xFF,alphaInt: 0xFF)
                prefs.setColor(color, forKey: "wallpaper_color")
                self.wallpaperView?.backgroundColor = color
                })
            alert.addAction(UIAlertAction(title: NSLocalizedString("color_grey", comment: ""), style: .default){ alertAction in
                prefs.set(nil, forKey: "wallpaper_path")
                self.wallpaperView?.image = nil
                
                let color = UIColor(redInt: 0xDD,greenInt: 0xDD,blueInt: 0xDD,alphaInt: 0xFF)
                prefs.setColor(color, forKey: "wallpaper_color")
                self.wallpaperView?.backgroundColor = color
                })
            alert.addAction(UIAlertAction(title: NSLocalizedString("color_beige", comment: ""), style: .default){alertAction in
                prefs.set(nil, forKey: "wallpaper_path")
                self.wallpaperView?.image = nil
                
                let color = UIColor(redInt: 0xFF,greenInt: 0xF5,blueInt: 0xF5,alphaInt: 0xFF)
                prefs.setColor(color, forKey: "wallpaper_color")
                self.wallpaperView?.backgroundColor = color
                })
            alert.addAction(UIAlertAction(title: NSLocalizedString("color_lightblue", comment: ""), style: .default){alertAction in
                prefs.set(nil, forKey: "wallpaper_path")
                self.wallpaperView?.image = nil
                
                let color = UIColor(redInt: 0xAD,greenInt: 0xD8,blueInt: 0xE6,alphaInt: 0xFF)
                prefs.setColor(color, forKey: "wallpaper_color")
                self.wallpaperView?.backgroundColor = color
                })
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("cancel",comment:""), style: .cancel, handler: nil))
            
            alert.popoverPresentationController?.sourceView = cell
            
            present(alert, animated: true, completion: nil)
        } else if(indexPath.section == 3){
            if(indexPath.row == 0){
                UIApplication.shared.openURL(URL(string: NSLocalizedString("howto_url", comment: ""))!)
                Adjust.trackEvent(ADJEvent(eventToken: "7dvi3i"))
            } else{
                let url:URL? = Bundle.main.url(forResource: cell.reuseIdentifier, withExtension:"html")
                openURL(url)
            }
        } else if(indexPath.section == 4){
            let url:URL? = Bundle.main.url(forResource: cell.reuseIdentifier, withExtension:"html")
            openURL(url)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            wallpaperView?.image = pickedImage
            
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
                if let dir : NSString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first as NSString? {
                    let localPath = dir.appendingPathComponent("\(GlobalQuestionData.user_id)/background.png")
                    let compressed = UIImageJPEGRepresentation(pickedImage, 1.0)
                    let folder = dir.appendingPathComponent("\(GlobalQuestionData.user_id)")
                    do{
                        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
                    } catch let error as NSError{
                        print(error.localizedDescription)
                    }
                    
                    if ((try? compressed?.write(to: URL(fileURLWithPath: localPath), options: [])) != nil) {
                        let prefs = UserDefaults.standard
                        prefs.set("\(GlobalQuestionData.user_id)/background.png", forKey: "wallpaper_path")
                        prefs.setColor(nil, forKey: "wallpaper_color")
                    }
                }
            }
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
}
