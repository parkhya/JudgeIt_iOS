//
//  ResponseCode.swift
//  Judge it
//
//  Created by Daniel Thevessen on 15/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation

public enum ResponseCode : Int {
    case SERVER_ERROR = 0, OK, FAIL, NO_ACCOUNT, WRONG_PASSWORD, CHECK_NOTHING, CHECK_NEW, NOT_FOUND, VERSION_MISMATCH, ACCOUNT_EXISTS, AUTHENTICATION_ERROR
    
    static func okayResponseCodes() -> [ResponseCode] {
        return [OK, CHECK_NOTHING, CHECK_NEW]
    }
    
    static func errorResponseCodes() -> [ResponseCode] {
        return [SERVER_ERROR, FAIL, NO_ACCOUNT, WRONG_PASSWORD, NOT_FOUND, VERSION_MISMATCH, ACCOUNT_EXISTS, AUTHENTICATION_ERROR]
    }
}
