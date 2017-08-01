//
//  DatePickerController.swift
//  Judge it!
//
//  Created by Daniel Thevessen on 02/03/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation

class DatePickerController : UIViewController {

    @IBOutlet var datePicker: UIDatePicker!
    @IBOutlet var timeframePicker: UIDatePicker!
    
    @IBAction func timeframeSwitched(_ sender: UISwitch) {
        timeframePicker.isHidden = !sender.isOn
    }

}
