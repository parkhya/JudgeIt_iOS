//
//  NewDatePickerController.swift
//  Judge it!
//
//  Created by Daniel Thevessen on 10/01/2017.
//  Copyright © 2017 Judge it. All rights reserved.
//

import Foundation
import FSCalendar

class NewDatePickerController : UIViewController, FSCalendarDelegate, FSCalendarDataSource {
    
    @IBOutlet var calendar: FSCalendar!
    
    var dates = [Date]()
    
    var isTimeframe = false
    var timeframe:(Date, Date)?
    
    @IBAction func timeframeSwitch(_ sender: UISwitch) {
        isTimeframe = sender.isOn
        
        if(isTimeframe){
            dates.removeAll()
            for date in calendar.selectedDates{
                calendar.deselect(date)
            }
        } else{
            timeframe = nil
            for date in calendar.selectedDates{
                calendar.deselect(date)
            }
        }
    }
    
    override func viewDidLoad() {
        calendar.allowsMultipleSelection = true
        
        
        calendar.firstWeekday = 2
        calendar.setCurrentPage(Date(), animated: false)
        calendar.swipeToChooseGesture.isEnabled = true
        
        super.viewDidLoad()
    }
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date) {
        if !isTimeframe{
            dates.append(date)
        } else{
            if (timeframe?.0.timeIntervalSince1970 ?? 0) > date.timeIntervalSince1970{
                timeframe = (date, timeframe?.1 ?? date)
            } else {
                timeframe = (timeframe?.0 ?? date, date)
            }
        }
    }
    
    func calendar(_ calendar: FSCalendar, didDeselect date: Date) {
        if !isTimeframe{
            dates.removeObject(date)
        } else{
            if date == timeframe?.0 {
                let next_day = (Calendar.current as NSCalendar).date(byAdding: .day, value: 1, to: date, options: [])
                timeframe = (next_day!, timeframe!.1)
            } else {
                let previous_day = (Calendar.current as NSCalendar).date(byAdding: .day, value: -1, to: date, options: [])
                timeframe = (timeframe!.0, previous_day!)
            }
            
            if(timeframe!.0.timeIntervalSince1970 > timeframe!.1.timeIntervalSince1970){
                timeframe = nil
            }
        }
    }
    
    func calendar(_ calendar: FSCalendar, shouldSelect date: Date) -> Bool {
        if !isTimeframe{
            return true
        }
        
        if let timeframe = timeframe {
            let day = (Calendar.current as NSCalendar).ordinality(of: .day, in: .era, for: date)
            
            let day_from = (Calendar.current as NSCalendar).ordinality(of: .day, in: .era, for: timeframe.0)
            let day_to = (Calendar.current as NSCalendar).ordinality(of: .day, in: .era, for: timeframe.1)
            
            return day == day_from-1 || day == day_to+1
        }
        
        return true
    }
    
    func calendar(_ calendar: FSCalendar, shouldDeselect date: Date) -> Bool {
        if !isTimeframe {
            return true
        }
        
        if let timeframe = timeframe {
            let day = (Calendar.current as NSCalendar).ordinality(of: .day, in: .era, for: date)
            
            let day_from = (Calendar.current as NSCalendar).ordinality(of: .day, in: .era, for: timeframe.0)
            let day_to = (Calendar.current as NSCalendar).ordinality(of: .day, in: .era, for: timeframe.1)
            
            return day == day_from || day == day_to
        }
        
        return true
    }
    
    func minimumDate(for calendar: FSCalendar) -> Date {
        return Date()
    }
    
    func maximumDate(for calendar: FSCalendar) -> Date {
        return (Calendar.current as NSCalendar)
            .date(
                byAdding: .year,
                value: 1,
                to: Date(),
                options: []
            )!
    }
    
    //    func getDateRanges(){
    //        let sortedDates = dates.sort({$0.0.timeIntervalSince1970 < $0.1.timeIntervalSince1970})
    //    }
    
}
