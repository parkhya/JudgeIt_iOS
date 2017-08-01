//
//  Model.swift
//  Judge it!
//
//  Created by Axel Katerbau on 27.08.16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

let TEST_ENVIRONMENT = false

let API_URL_STRING: String = TEST_ENVIRONMENT ? "https://judgeit-test.eu-central-1.elasticbeanstalk.com/api" : "https://api.judge-it.net/api"

let manager: Manager = {
    let serverTrustPolicies: [String: ServerTrustPolicy] = [
        "api.judge-it.net": .DisableEvaluation
    ]
    
    let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
    var headers = Alamofire.Manager.defaultHTTPHeaders
    headers["Content-Type"] = "application/json"
    headers["Accept"] = "application/json"

    configuration.HTTPAdditionalHeaders = headers
    
    return Alamofire.Manager(configuration: configuration,
                             serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies))
}()

func request(parameters parameters: [String: AnyObject]?,
             cachedWithMaxAge: NSTimeInterval,
             wantsCurrentVersionIfOlderThan: NSTimeInterval,
             completion: (JSON?, ErrorType?) -> Void) {
    
    var parameters = parameters ?? [String: AnyObject]()
    
    parameters["user_id"] = GlobalQuestionData.user_id
    parameters["login_token"] = GlobalQuestionData.login_token
    parameters["version"] = Communicator.SERVER_VERSION
    parameters["debug"] = false
    
    manager.request(.POST, API_URL_STRING, parameters: parameters, encoding: .JSON, headers: nil)
        .responseData { response in
            if let value = response.result.value {
                let json = JSON(data: value)
                print(json)
            }
    }
        
}

func fetchAll() {
    var parameters: [String : AnyObject] = ["request_type" : RequestType.CHECK_FOR_UPDATE.rawValue,
                                            "startup" : true]
//    parameters["from_date"] = Int(NSDate().timeIntervalSince1970 - 28 * 24 * 60 * 60)

    parameters["skip_questions"] = [Int]()

    request(parameters: parameters, cachedWithMaxAge: 0, wantsCurrentVersionIfOlderThan: 0, completion: { json, error in
    })
}

/*
- (NSURLSessionDataTask *)URLSessionDataTaskWithURLString:(NSString *)URLString method:(NSString *)httpMethod parameters:(NSDictionary *)parameters cachedWithMaxAge:(NSTimeInterval)maxAge wantsCurrentVersionIfOlderThan:(NSTimeInterval)wantsCurrentVersionIfOlderThan completion:(BGSAPIClientObjectCompletionBlock)completionBlock {
    NSURLSessionDataTask *result = nil;
    NSString *requestURLString = nil;
    
    parameters = parameters ? : @{};
    
    NSString *isoLanguageCode = [[NSBundle mainBundle] preferredLocalizations].firstObject;
    parameters = [parameters dictionaryBySettingObject:isoLanguageCode forKey:@"lang"];
    
    if ([URLString hasPrefix:@"http"]) {
        requestURLString = URLString;
    } else {
        requestURLString = [self.sessionManager.baseURL.absoluteString stringByAppendingPathComponent:URLString];
    }
    
    NSURLRequest *request = [self.sessionManager.requestSerializer requestWithMethod:httpMethod URLString:requestURLString parameters:parameters error:NULL];
    
    id cachedObject = nil;
    NSTimeInterval timeInterval = 0;
    
    if (maxAge > 0) {
        cachedObject = [self cachedObjectForRequest:request withMaxAge:maxAge actualTimeInterval:&timeInterval];
        
        if (cachedObject) {
            DDLogInfo(@"Cache hit for request: %@", request);
            
            if (completionBlock) completionBlock(cachedObject, nil);
        }
    }
    
    BOOL wantsCurrentVersion = (wantsCurrentVersionIfOlderThan == 0) || (timeInterval < ([[NSDate date] timeIntervalSince1970] - wantsCurrentVersionIfOlderThan));
    
    if (!cachedObject || wantsCurrentVersion) {
        NSString *pendingBlocksKey = [NSString stringWithFormat:@"%@|%@|%@|%lf|%lf", request.URL, httpMethod, request.HTTPBody, maxAge, wantsCurrentVersionIfOlderThan];
        //        NSLog(@"pendingBlocksKey: %@", pendingBlocksKey);
        NSMutableArray *objectCompletionBlocks = self.pendingObjectCompletionBlocks[pendingBlocksKey];
        BOOL serverRequestAlreadyInQueue = objectCompletionBlocks != nil;
        
        if (completionBlock) {
            if (!objectCompletionBlocks) {
                objectCompletionBlocks = [NSMutableArray arrayWithObject:[completionBlock copy]];
                self.pendingObjectCompletionBlocks[pendingBlocksKey] = objectCompletionBlocks;
            } else {
                [objectCompletionBlocks addObject:[completionBlock copy]];
            }
        }
        
        if (!serverRequestAlreadyInQueue) {
            self.sessionSuspended = NO; // re-activate position sending / infobar polling etc.
            
            //DDLogInfo(@"Loading new version for request: %@", pendingBlocksKey);
            
            DDLogInfo(@"Requesting server URL: %@ with parameters: %@", URLString, [parameters.description substringUpToIndex:300]);
            //            if ([request.URL.description containsString: @"/jsn/default.asp?get=user"]) {
            //                NSLog(@"honk (%@)!", pendingBlocksKey);
            //            }
            __block NSURLSessionDataTask *task = [self.sessionManager dataTaskWithRequest:request completionHandler:^(NSURLResponse *__unused response, id __unused responseObject, NSError *error) {
                if (error) {
                [self postProcessServerAccessWithTask:task responseObject:responseObject error:error completion:^(id object, NSError *error) {
                @try {
                for (BGSAPIClientObjectCompletionBlock block in self.pendingObjectCompletionBlocks[pendingBlocksKey]) {
                block(object, error);
                }
                } @catch (NSException *exception) {
                DDLogError(@"Exception during callback processing %@: %@", pendingBlocksKey, exception);
                } @finally {
                [self.pendingObjectCompletionBlocks removeObjectForKey:pendingBlocksKey];
                //
                //                            if ([request.URL.description containsString: @"/jsn/default.asp?get=user"]) {
                //                                NSLog(@"honk removed (%@)!", pendingBlocksKey);
                //                            }
                //
                }
                }];
                } else {
                if (![cachedObject isEqual:responseObject]) {
                //DDLogInfo(@"Loaded version differs, using it: %@", pendingBlocksKey);
                [self postProcessServerAccessWithTask:task responseObject:responseObject error:nil completion:^(NSDictionary *processedObject, NSError *error) {
                if (!error && maxAge > 0) {
                [self cacheObject:processedObject withRequest:request response:task.response];
                }
                
                @try {
                for (BGSAPIClientObjectCompletionBlock block in [self.pendingObjectCompletionBlocks[pendingBlocksKey] copy]) {
                block(processedObject, error);
                }
                } @catch (NSException *exception) {
                DDLogError(@"Exception during callback processing %@: %@", pendingBlocksKey, exception);
                } @finally {
                [self.pendingObjectCompletionBlocks removeObjectForKey:pendingBlocksKey];
                //
                //                                if ([request.URL.description containsString: @"/jsn/default.asp?get=user"]) {
                //                                    NSLog(@"honk removed (%@)!", pendingBlocksKey);
                //                                }
                //
                }
                }];
                } else {
                [self.pendingObjectCompletionBlocks removeObjectForKey:pendingBlocksKey];
                DDLogInfo(@"Server version SAME as cache! NOT using it: %@", pendingBlocksKey);
                //                        if ([request.URL.description containsString: @"/jsn/default.asp?get=user"]) {
                //                            NSLog(@"honk removed (%@)!", pendingBlocksKey);
                //                        }
                }
                }
                }];
            
            [task resume];
            result = task;
        } else {
            //DDLogInfo(@"Doin' nuthin. Already requested server: %@ with parameters: %@", URLString, parameters);
        }
    }
    
    return result;
}
*/