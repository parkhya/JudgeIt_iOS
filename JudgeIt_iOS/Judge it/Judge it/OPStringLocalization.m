//
//  NSView+OPStringLocalization.m
//
//  Created by Dirk Theisen on Thu Jan 16 2003.
//  Copyright (c) 2003-2016 Objectpark Software. All rights reserved.
//

#import "OPStringLocalization.h"

@interface NSObject (OPStringLocalization)
- (void)localizeStringProperty:(NSString *)aProperty;
@end

@implementation NSObject (OPStringLocalization)

- (void)localizeStringProperty:(NSString *)aProperty {
    NSString *propertyValue = [self valueForKey:aProperty];
    
    if ([propertyValue length]) {
        //		NSLog(@"localizing property '%@' original='%@', localized='%@'", aProperty, propertyValue, LS(propertyValue, @""));
        [self setValue:NSLocalizedString(propertyValue, @"") forKey:aProperty];
    }
}

@end

@implementation UIViewController (OPStringLocalization)

- (id)localizeStrings {
    [self.view localizeStrings];
    [self.navigationItem localizeStrings];
    [self.tabBarItem localizeStrings];
    return self;
}

@end


@implementation UITableViewController (OPStringLocalization)

- (id) localizeStrings {
    
    [self.navigationItem localizeStrings];
    [self.tabBarItem localizeStrings];

    // Localize the cells of static UITableViews:
    if (self == self.tableView.dataSource && [self valueForKey:@"staticDataSource"]) {
        NSInteger numberOfSections = [self.tableView numberOfSections];
        
        // Save scroll position here
        CGPoint scrollPos = self.tableView.contentOffset;
        
        // Enumerate over all static cells:
        for (NSInteger section = 0; section < numberOfSections; section++) {
            NSInteger numberOfRows = [self.tableView numberOfRowsInSection:section];
            
            for (NSInteger row = 0; row < numberOfRows; row++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForItem:row inSection:section];
                [self.tableView scrollToRowAtIndexPath: indexPath atScrollPosition: UITableViewScrollPositionMiddle animated: NO];
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                if (! cell) {
                    NSLog(@"Error localizing tableview cell at %@", indexPath);
                }
                [cell localizeStrings];
            }
        }
        
        // Restore scroll position
        self.tableView.contentOffset = scrollPos;
    }
    return self;
}

@end


@implementation UIView (OPStringLocalization)

/*" Localize all strings (titles, labels etc.) including all subviews. Uses the simple NSLocalizedString for the translation. "*/
- (id) localizeStrings {
    for (UIView *subview in [self subviews]) {
        //        NSLog(@"Localizing strings in %@. Descending into %d subviews.", self, [[self subviews] count]);
        [subview localizeStrings];
    }
    return self;
}

@end


@implementation UISearchBar (OPStringLocalization)

- (id) localizeStrings {
    [super localizeStrings];
    [self localizeStringProperty:@"text"];
    [self localizeStringProperty:@"placeholder"];
    [self localizeStringProperty:@"prompt"];
    return self;
}

@end


@implementation UINavigationItem (OPStringLocalization)

- (id) localizeStrings {
    [self localizeStringProperty:@"title"];
    [self localizeStringProperty:@"prompt"];
    [self.titleView localizeStrings];
    [self.backBarButtonItem localizeStringProperty:@"title"];
    [self.leftBarButtonItem localizeStringProperty:@"title"];
    [self.rightBarButtonItem localizeStringProperty:@"title"];
    return self;
}

@end

@implementation UINavigationBar (OPStringLocalization)

- (id) localizeStrings {
    for (UINavigationItem *item in self.items) {
        [item localizeStrings];
    }
    
    return [super localizeStrings];
}

@end

@implementation UISegmentedControl (OPStringLocalization)

- (id) localizeStrings {
    for (NSInteger segment = self.numberOfSegments - 1; segment >= 0; segment--) {
        NSString *originalTitle = [self titleForSegmentAtIndex:segment];
        [self setTitle:LS(originalTitle) forSegmentAtIndex:segment];
    }
    
    return [super localizeStrings];
}

@end

@implementation UIToolbar (OPStringLocalization)

- (id) localizeStrings {
    for (UINavigationItem *item in self.items) {
        [item localizeStrings];
    }
    
    return [super localizeStrings];
}

@end

@implementation UILabel (OPStringLocalization)

- (id) localizeStrings {
    //    NSAttributedString* attrString = self.attributedText;
    //    if (attrString) {
    //        NSLog(@"localizing label '%@'", attrString.string);
    //    }
    //        self.attributedText = [[NSAttributedString alloc] initWithString: LS(attrString.string, @"") attributes: [attrString attributesAtIndex: attrString.length-1 effectiveRange: NULL]];
    //    } else {
    [self localizeStringProperty:@"text"];
    //    }
    return [super localizeStrings];
}

@end

@implementation UITextView (OPStringLocalization)

- (id) localizeStrings {
    [self localizeStringProperty:@"text"];
    return [super localizeStrings];
}

@end

@implementation UITextField (OPStringLocalization)

- (id) localizeStrings {
    [self localizeStringProperty:@"placeholder"];
    return [super localizeStrings];
}

@end

@implementation UIBarItem (OPStringLocalization)

- (id) localizeStrings {
    [self localizeStringProperty:@"title"];
    return self;
}

@end

@implementation UIButton (OPStringLocalization)

- (id) localizeStrings {
    NSString *title;
    
    title = [self titleForState:UIControlStateNormal];
    
    if ([title length]) [self setTitle:LS(title) forState:UIControlStateNormal];
    
    title = [self titleForState:UIControlStateHighlighted];
    
    if ([title length]) [self setTitle:LS(title) forState:UIControlStateHighlighted];
    
    title = [self titleForState:UIControlStateDisabled];
    
    if ([title length]) [self setTitle:LS(title) forState:UIControlStateDisabled];
    
    title = [self titleForState:UIControlStateSelected];
    
    if ([title length]) [self setTitle:LS(title) forState:UIControlStateSelected];
    
    return [super localizeStrings];
}

@end

@implementation UIAlertView (OPStringLocalization)

- (id) localizeStrings {
    
    [self localizeStringProperty: @"title"];
    [self localizeStringProperty: @"message"];
    @try {
        NSArray* buttons = [self valueForKey: @"buttons"];
        [buttons makeObjectsPerformSelector: _cmd];
    }
    @catch (NSException *exception) {
    }
    
    return self;
}

@end
