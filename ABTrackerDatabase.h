//
//  ABTrackerDatabase.h
//  Autobake
//
//  Created by Nick Zitzmann on 3/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ABTrackerDatabase : NSObject
{
	NSArray *_signatures;
}
- (BOOL)isCookieATrackingCookie:(NSHTTPCookie *)cookie why:(NSString **)description;

@end
