//
//  OPKeyboardStateListener.h
//  Judge it!
//
//  Created by Dirk Theisen on 06.10.16.
//  Copyright © 2016 Objectpark Software GbR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OPKeyboardStateListener : NSObject

+ (OPKeyboardStateListener *)sharedInstance;

- (BOOL) isVisible;

@end
