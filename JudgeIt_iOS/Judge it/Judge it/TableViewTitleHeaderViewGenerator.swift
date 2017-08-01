//
//  TableViewTitleHeaderViewGenerator.swift
//  Judge it!
//
//  Created by Axel Katerbau on 04.10.16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import UIKit

func makeTableViewHeaderView(title: String, textAlignment: NSTextAlignment = .center, width: CGFloat, fontFamilyName: String) -> UIView {
    let result = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: 26))
    result.textAlignment = textAlignment
    result.backgroundColor = UIColor.groupTableViewBackground
    result.textColor = UIColor.black
    if(fontFamilyName.characters.count > 0) {
        result.font = UIFont(name: "Amatic-Bold", size: 18.5)
    } else {
        result.font = UIFont(name: "CabinCondensed-Bold", size: 17)
        //result.font = UIFont.boldSystemFont(ofSize: 17)
    }
    result.text = title
    return result
}
