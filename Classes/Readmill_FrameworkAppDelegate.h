//
//  Readmill_FrameworkAppDelegate.h
//  Readmill Framework
//
//  Created by Work on 10/01/2011.
//  Copyright 2011 KennettNet Software Limited. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ReadmillUser.h"
#import "ReadmillRead.h"

@interface Readmill_FrameworkAppDelegate : NSObject <NSApplicationDelegate, 
ReadmillUserAuthenticationDelegate, 
ReadmillBookFindingDelegate,
ReadmillReadFindingDelegate,
ReadmillReadUpdatingDelegate> {
    
    NSWindow *window;
    ReadmillUser *user;
}

@property (assign) IBOutlet NSWindow *window;
@property (readwrite, retain) ReadmillUser *user;

@end
