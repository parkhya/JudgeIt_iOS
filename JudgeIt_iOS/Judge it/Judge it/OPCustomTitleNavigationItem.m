//
//  OPCustomTitleNavigationItem.m
//  Judge it!
//
//  Created by Dirk Theisen on 16.09.16.
//  Copyright © 2016 Judge it. All rights reserved.
//

#import "OPCustomTitleNavigationItem.h"

@implementation OPCustomTitleNavigationItem {
    IBOutlet UILabel* titleLabel;
    
    IBOutlet UILabel *lbl_Title;
    IBOutlet UILabel *lbl_Logo;
    IBOutlet UIView *view_Black;
//    IBOutlet UIView* customTitleView;
}

- (void) loadFromNib {
    [[NSBundle mainBundle] loadNibNamed: @"CustomTitleNavigationItem" owner: self options: nil];
    //self.titleView = customTitleView;
    titleLabel.text = NSLocalizedString(self.title, @""); // initial synchronization
}

- (id) initWithTitle: (NSString*) aTitle {
    if (self = [super initWithTitle: aTitle]) {
        [self loadFromNib];
    }
    return self;
}

- (id) initWithCoder: (NSCoder*) coder {
    if (self = [super initWithCoder: coder]) {
        // load from nib
        [self loadFromNib];
    }
    return self;
}

- (void) setTitle: (NSString*) newTitle {
    [super setTitle: newTitle];
    titleLabel.text = newTitle;
    lbl_Title.text = newTitle;
    /*
    NSUserDefaults * def = [NSUserDefaults standardUserDefaults];
    if([def objectForKey:@"selectedClass"] != nil) {
        if([[def objectForKey:@"selectedClass"] isEqualToString:@"Question"] || [[def objectForKey:@"selectedClass"] isEqualToString:@"Add Contacts"]) {
            lbl_Title.text = newTitle;
            [view_Black setHidden:YES];
            [lbl_Logo setHidden:YES];
            [lbl_Title setHidden:NO];
        } else {
            lbl_Title.text = newTitle;
            [view_Black setHidden:NO];
            [lbl_Logo setHidden:NO];
            [lbl_Title setHidden:YES];
        }
    } else {
        lbl_Title.text = newTitle;
        [view_Black setHidden:NO];
        [lbl_Logo setHidden:NO];
        [lbl_Title setHidden:YES];
    } */
    NSLog(@"newTitle = %@", newTitle);
}



@end
