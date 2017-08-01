//
//  IDObfuscator.swift
//  Judge it
//
//  Created by Daniel Thevessen on 12/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation

class IDObfuscator {
    
    static let magicValues = [364923845, 2032850928, 987473021]
    
    static func obfuscate(_ question_id:Int) -> String{
        
        var obfuscated = question_id
        for xorVal in magicValues{
            obfuscated = obfuscated ^ xorVal
        }
        return String(obfuscated, radix:16)
    }
    
    static func deObfuscate(_ obfuscated: String?) -> Int?{
        
        if let obfuscated = obfuscated,
            let obfuscated_num = Int(obfuscated, radix: 16){
                var question_id = obfuscated_num
                for xorVal in magicValues.reversed(){
                    question_id = question_id ^ xorVal
                }
                return question_id
        }
        return nil
    }
    
}
