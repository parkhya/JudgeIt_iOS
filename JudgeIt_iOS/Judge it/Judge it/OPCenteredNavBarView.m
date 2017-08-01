//
//  NavBarView.m
//  Judge it!
//
//  Created by Dirk Theisen on 02.09.16.
//  Copyright © 2016 Judge it. All rights reserved.
//

#import "OPCenteredNavBarView.h"

@implementation OPCenteredNavBarView {
}


/**
 * Make sure, this does get margins left and right.
 */
//- (void)setFrame:(CGRect)frame {
//    [super setFrame:CGRectMake(frame.origin.x-32, frame.origin.y, frame.size.width+64, frame.size.height)];
//}

//- (void) awakeFromNib {
//    [super awakeFromNib];
//    UIView* titleLabel = [self viewWithTag: 101];
//    titleLabelCenterXConstraint = [NSLayoutConstraint constraintWithItem: titleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f];
//    UIView* subtitleLabel = [self viewWithTag: 102];
//    subtitleLabelCenterXConstraint = [NSLayoutConstraint constraintWithItem: subtitleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f];
//
//}
//
//
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat screenCenter = CGRectGetMidX([UIScreen mainScreen].bounds);
    CGFloat diffCenter = screenCenter - CGRectGetMidX(self.frame);
    if (diffCenter>0) {
        titleBoxLeadingConstraint.constant = diffCenter*2;
        titleBoxTrailingConstraint.constant = 0;
    } else {
        titleBoxLeadingConstraint.constant = 0;
        titleBoxTrailingConstraint.constant = -diffCenter*2;
    }

}

//- (void) setFrame:(CGRect)frame {
//    [super setFrame: frame];
//    NSLog(@"NavBarView frame = %@", NSStringFromCGRect(self.frame));
//}


@end
