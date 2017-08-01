//
//  OPKeyboardStateListener.m
//  Judge it!
//
//  Created by Dirk Theisen on 06.10.16.
//  Copyright © 2016 Objectpark Software GbR. All rights reserved.
//

#import "OPKeyboardStateListener.h"
#import <UIKit/UIKit.h>

static OPKeyboardStateListener *sharedInstance;

@implementation OPKeyboardStateListener {
    BOOL _isVisible;
}

+ (OPKeyboardStateListener *)sharedInstance
{
    return sharedInstance;
}

+ (void) load {
    if (! sharedInstance) {
        sharedInstance = [[self alloc] init];
    }
}

- (BOOL) isVisible {
    return _isVisible;
}

- (void) didShow {
    _isVisible = YES;
}

- (void) didHide {
    _isVisible = NO;
}

- (id) init {
    if ((self = [super init])) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver: self selector: @selector(didShow) name:UIKeyboardDidShowNotification object:nil];
        [center addObserver:self selector:@selector(didHide) name:UIKeyboardWillHideNotification object:nil];
    }
    return self;
}

@end
