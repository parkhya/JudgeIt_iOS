//
//  RequestType.swift
//  Judge it
//
//  Created by Daniel Thevessen on 15/09/15.
//  Copyright (c) 2015 Judge it. All rights reserved.
//

import Foundation

public enum RequestType : Int{
    case REGISTER_ANON = 0
    case CLAIM_ACCOUNT
    case INVITE_QUESTION
    case LOAD_QUESTION
    case SUBMIT_VOTE
    case GET_USERDATA
    case COMMENT
    case LOGIN
    case CHECK_FOR_UPDATE
    case UPDATE_PROFILE
    case CREATE
    case LOGOUT
    case CONTACTS
    case INVITE_GROUP
    case PASSWORD_RESET
    case GCM
    case SYNC_MUTE
}
