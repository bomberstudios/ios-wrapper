//
//  UIApplication+ReadmillNetworkActivity.h
//  ReadmillAPI
//
//  Created by Martin Hwasser on 12/2/11.
//  Copyright (c) 2011 Readmill Network LTD. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIApplication (ReadmillNetworkActivity)

@property (nonatomic, assign, readonly) NSInteger readmill_networkActivityCount;

- (void)readmill_pushNetworkActivity;
- (void)readmill_popNetworkActivity;
- (void)readmill_resetNetworkActivity;

@end
