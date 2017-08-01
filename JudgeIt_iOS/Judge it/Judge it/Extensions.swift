//
//  Extensions.swift
//  Judge it
//
//  Created by Daniel Thevessen on 24/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation

extension String{
    func trim() -> String{
        return self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    var length:Int {
        return self.characters.count
    }
    
    func removeWhitespace() -> String {
        return String(self.characters.filter({$0 != " "}))
    }
    
    func rawId() -> Int? {
        let components = self.components(separatedBy: "/")
        if components.count > 0 {
            return Int(components.last!)
        }
        
        return nil
    }
}

extension Array {
    subscript (safe index: Int) -> Element? {
        return indices ~= index ? self[index] : nil
    }
}

extension Array where Element : Equatable{
    mutating func removeObject(_ object: Element) -> Bool{
        if let index = self.index(of: object){
            self.remove(at: index)
            return true
        }
        return false
    }
}

extension Array where Element: UserListItem{
    
    mutating func removeObject(_ otherUserItem: Element) -> Bool{
        let oldCount = self.count
        self = self.filter({userItem in
            if let user = userItem as? User, let otherUser = otherUserItem as? User, user.user_id == otherUser.user_id{
                return false
            }
            if let group = userItem as? UserGroup, let otherGroup = otherUserItem as? UserGroup, group.group_id == otherGroup.group_id {
                return false
            }
            return true
        })
        return oldCount != self.count
    }
    
}

extension Date {
    
    static func timeString(fromUnixTime time: Double) -> String {
        return timeString(fromUnixTime: time, weekDay: false)
    }
    
    static func timeString(fromUnixTime time: Double, weekDay: Bool) -> String {
        let date = Date(timeIntervalSince1970: time)
        
        let dateFormatter1 = DateFormatter()
        let localizedMonth = DateFormatter.dateFormat(fromTemplate: "MMMd", options: 0, locale: Locale.current)
        dateFormatter1.dateFormat = weekDay ? "EEE, \(localizedMonth!)" : "\(localizedMonth!)"
        dateFormatter1.timeZone = TimeZone.current
        
        let dateFormatter2 = DateFormatter()
        dateFormatter2.locale = Locale.current
        dateFormatter2.dateFormat = "HH:mm"
        dateFormatter2.timeZone = TimeZone.current
        
        return dateFormatter1.string(from: date) + ", " + dateFormatter2.string(from: date)
    }
    
    static func dateString(fromUnixTime time: Double, weekDay: Bool) -> String {
        let date = Date(timeIntervalSince1970: time)
        
        let dateFormatter1 = DateFormatter()
        let localizedMonth = DateFormatter.dateFormat(fromTemplate: "MMMd", options: 0, locale: Locale.current)
        dateFormatter1.dateFormat = weekDay ? "EEE, \(localizedMonth!)" : "\(localizedMonth!)"
        dateFormatter1.timeZone = TimeZone.current
        
        return dateFormatter1.string(from: date)
    }
    
    @nonobjc static let WMCDateformatter = { () -> DateFormatter in
        var formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    @nonobjc static let RFC1123DateFormatter: DateFormatter = {
        var formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        return formatter
    }()
}

// Shorthand for 0 to 255 values instead of 0 to 1
extension UIColor {
    convenience init(redInt: Int, greenInt:Int, blueInt:Int, alphaInt: Int) {
        self.init(red: CGFloat(redInt) / 255.0, green: CGFloat(greenInt) / 255.0, blue: CGFloat(blueInt) / 255.0, alpha: CGFloat(alphaInt) / 255.0)
    }
    
    convenience init(red: Int, green:Int, blue:Int){
        self.init(redInt:red, greenInt:green, blueInt:blue, alphaInt: 0xff)
    }
    
    @nonobjc static let judgeItPrimaryColor = UIColor(red: 0xFF, green: 0x45, blue: 0x4D)
    @nonobjc static let judgeItLightColor = UIColor(red: 0xFF, green: 0xF3, blue: 0xF3)
    @nonobjc static let judgeItUpvoteColor = UIColor(redInt: 0x39, greenInt: 0xA1, blueInt: 0x06, alphaInt: 0xFF)
//    @nonobjc static let judgeItUpvoteColor = UIColor(redInt: 0x13, greenInt: 0x9C, blueInt: 0xAA, alphaInt: 0xFF)
    @nonobjc static let judgeItDownvoteColor = UIColor(redInt: 0xD7, greenInt: 0x23, blueInt: 0x16, alphaInt: 0xFF)
    @nonobjc static let judgeItBorderColor = UIColor(redInt: 0xD0, greenInt: 0xD0, blueInt: 0xD0, alphaInt: 0xFF)
    
}

extension UserDefaults {
    
    func colorForKey(_ key: String) -> UIColor? {
        var color: UIColor?
        if let colorData = data(forKey: key) {
            color = NSKeyedUnarchiver.unarchiveObject(with: colorData) as? UIColor
        }
        return color
    }
    
    func setColor(_ color: UIColor?, forKey key: String) {
        var colorData: Data?
        if let color = color {
            colorData = NSKeyedArchiver.archivedData(withRootObject: color)
        }
        set(colorData, forKey: key)
    }
    
}

extension UIViewController {
    
    /**
     * Returns the previous UIViewController on the NavigationVontroller stack.
     */
    func previousViewController() -> UIViewController? {
        if let stack = self.navigationController?.viewControllers {
            for i in stride(from: (stack.count-1), to: 0, by: -1) {
                if (stack[i] == self) {
                    return stack[i-1]
                }
            }
        }
        return nil
    }
    
}

extension UINavigationController {
    
    func popToViewControllerOfClass(_ aClass: AnyClass,
                                    animated animate: Bool) -> [UIViewController]? {
        
        let stack = self.viewControllers
        for i in stride(from: (stack.count-1), through: 0, by: -1) {
            let vc: UIViewController = stack[i]
            if (vc.isKind(of: aClass)) {
                return self.popToViewController(vc, animated: animate)
            }
        }
        return self.viewControllers
    }
    
}


extension UIView {
    func findFirstResponder() -> UIView? {
        if (self.isFirstResponder) {
            return self
        }
        for subView in self.subviews {
            if let responder = subView.findFirstResponder(){
                return responder
            }
        }
        return nil
    }
    
    func takeScreenshot() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
        
        drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        
        // old style: layer.renderInContext(UIGraphicsGetCurrentContext())
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
}

extension UIImage {
    
    func imageWithAddedBorder(_ borderSize: CGFloat, color: UIColor) -> UIImage {
        let targetSize = CGSize(width: self.size.width + (borderSize * 2), height: self.size.height + (borderSize * 2))
        UIGraphicsBeginImageContext(targetSize)
        let rect = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(color.cgColor)
        context?.stroke(rect);
        
        let targetRect = CGRect(x: borderSize, y: borderSize, width: size.width, height: size.height);
        self.draw(in: targetRect, blendMode: .normal, alpha: 1)
        
        let result = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return result!;
    }
    
}

extension UIScrollView{
    func takeScreenshot(_ maxHeight: CGFloat?) -> UIImage {
        var image = UIImage()
        
        let size = CGSize(width: self.contentSize.width, height: maxHeight ?? self.contentSize.height)
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        
        // save initial values
        let savedContentOffset = self.contentOffset
        let savedFrame = self.frame
        let savedBackgroundColor = self.backgroundColor
        
        // reset offset to top left point
        self.contentOffset = CGPoint.zero;
        // set frame to content size
        self.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        // remove background
        self.backgroundColor = UIColor.white
        
        // make temp view with scroll view content size
        // a workaround for issue when image on ipad was drawn incorrectly
        let tempView = UIView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        // save superview
        let tempSuperView = self.superview
        // remove scrollView from old superview
        self.removeFromSuperview()
        // and add to tempView
        tempView.addSubview(self)
        
        // render view
        // drawViewHierarchyInRect not working correctly
        tempView.layer.render(in: UIGraphicsGetCurrentContext()!)
        // and get image
        image = UIGraphicsGetImageFromCurrentImageContext()!
        
        // and return everything back
        tempView.subviews[0].removeFromSuperview()
        tempSuperView?.addSubview(self)
        
        // restore saved settings
        self.contentOffset = savedContentOffset
        self.frame = savedFrame
        self.backgroundColor = savedBackgroundColor
        
        UIGraphicsEndImageContext()
        
        return image
    }
}

extension UIImage {
    func resizeToWidth(_ width:CGFloat)-> UIImage {
        let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))))
        imageView.contentMode = UIViewContentMode.scaleAspectFit
        imageView.image = self
        UIGraphicsBeginImageContext(imageView.bounds.size)
        imageView.layer.render(in: UIGraphicsGetCurrentContext()!)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result!
    }
}

extension UITableView {
    func scrollToEnd(_ animated: Bool) {
        let indexOfLastSection = self.numberOfSections - 1
        if indexOfLastSection >= 0 {
            //self.layoutIfNeeded() // force table view to finish updating
            let indexOfLastRow = self.numberOfRows(inSection: indexOfLastSection) - 1
            if (indexOfLastRow >= 0) {
                let indexPath = IndexPath(row: indexOfLastRow, section: indexOfLastSection)
                self.scrollToRow(at: indexPath, at: .bottom, animated: animated)
            }
        }
    }
}

extension URL {
    static func URL(string: String, fallbackSchemeWithDivider: String) -> Foundation.URL? {
        let candidate1 = Foundation.URL(string: string)
        if let candidate1 = candidate1, candidate1.scheme != "" {
            return candidate1
        }
        
        return Foundation.URL(string: fallbackSchemeWithDivider + string)
    }
}

extension UITabBarController {
    
    func indexOfItemWithTag(_ tag: Int) -> Int? {
        
        for (index, item) in (self.tabBar.items?.enumerated())! {
            if item.tag == tag {
                return index
            }
        }
        
        return nil
    }
}


extension NSAttributedString {
    func height(withConstrainedWidth width: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, context: nil)
        
        return ceil(boundingBox.height)
    }
    
    func width(withConstrainedHeight height: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, context: nil)
        
        return ceil(boundingBox.width)
    }
}

public extension UIDevice {
    
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        switch identifier {
        case "iPod5,1":                                 return "iPod Touch 5"
        case "iPod7,1":                                 return "iPod Touch 6"
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
        case "iPhone4,1":                               return "iPhone 4s"
        case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
        case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
        case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
        case "iPhone7,2":                               return "iPhone 6"
        case "iPhone7,1":                               return "iPhone 6 Plus"
        case "iPhone8,1":                               return "iPhone 6s"
        case "iPhone8,2":                               return "iPhone 6s Plus"
        case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
        case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
        case "iPhone8,4":                               return "iPhone SE"
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
        case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
        case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
        case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
        case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
        case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
        case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
        case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
        case "iPad6,3", "iPad6,4", "iPad6,7", "iPad6,8":return "iPad Pro"
        case "AppleTV5,3":                              return "Apple TV"
        case "i386", "x86_64":                          return "Simulator"
        default:                                        return identifier
        }
    }
    
    
}
