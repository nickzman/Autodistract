//
//  ABBaker.h
//  Autobake
//
//  Created by Nick Zitzmann on 3/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Growl/Growl.h>

@interface ABBaker : NSObject <GrowlApplicationBridgeDelegate>
{
	NSRecursiveLock *_threadLock;
}

@end
