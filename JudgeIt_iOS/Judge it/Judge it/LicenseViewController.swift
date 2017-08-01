//
//  LicenseViewController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 06/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation

class LicenseViewController : UIViewController {
    
    @IBOutlet weak var webView: UIWebView!
    var url:URL?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.localizeStrings()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        let request = URLRequest(url: url!)
        webView.loadRequest(request)
    }
    
}
