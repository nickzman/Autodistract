//
//  ABBaker.h
//  Autodistract
//
//  Created by Nick Zitzmann on 3/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Growl/Growl.h>

@class ABTrackerDatabase;

@interface ABBaker : NSObject <GrowlApplicationBridgeDelegate>
{
	NSRecursiveLock *_threadLock;
	ABTrackerDatabase *_database;
}

@end
