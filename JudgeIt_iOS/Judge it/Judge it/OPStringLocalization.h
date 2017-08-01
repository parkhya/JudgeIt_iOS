//
//  OPStringLocalization.h
//
//  Created by Dirk Theisen on Thu Jan 16 2003.
//  Copyright (c) 2003-2016 Objectpark Software. All rights reserved.
//

#import <UIKit/UIKit.h>

#define LS(localizableString) NSLocalizedString((localizableString),@"")
#define LSc(localizableString, comment) LS(localizableString)


//NSString * L(NSString * translation_key) {
//    NSString * s = NSLocalizedString(translation_key, nil);
//    if (![[[NSLocale preferredLanguages] objectAtIndex:0] isEqualToString:@"en"] && [s isEqualToString:translation_key]) {
//        NSString * path = [[NSBundle mainBundle] pathForResource:@"en" ofType:@"lproj"];
//        NSBundle * languageBundle = [NSBundle bundleWithPath:path];
//        s = [languageBundle localizedStringForKey:translation_key value:@"" table:nil];
//    }
//    return s;
//}

//static NSBundle* englishBundle = nil;
//
//static inline NSString* LS(NSString* string) {
//    NSString* result = NSLocalizedString(string, nil);
//    if (result == string && string.length>1) {
//        if (![[NSLocale preferredLanguages][0] hasPrefix: @"de-"]) {
//            
//            // no translation took place
//            // fall back to english:
//            if (! englishBundle) {
//                englishBundle = [NSBundle bundleWithPath: [[NSBundle mainBundle] pathForResource:@"en" ofType:@"lproj"]];
//            }
//            
//            result = [englishBundle localizedStringForKey: string value: nil table: nil];
//            if (result != string) {
//                NSLog(@"Using fallback localization for '%@'.", string);
//            }
//        }
//    }
//    return result;
//}


@interface UIView (OPStringLocalization)
- (id) localizeStrings;
@end

@interface UINavigationItem (OPStringLocalization)
- (id) localizeStrings;
@end

@interface UIViewController (OPStringLocalization)
- (id) localizeStrings;
@end

@interface UIBarItem (OPStringLocalization)
- (id) localizeStrings;
@end