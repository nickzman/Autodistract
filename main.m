//
//  main.m
//  Autodistract
//
//  Created by Nick Zitzmann on 3/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/objc-auto.h>
#import <Growl/Growl.h>
#import "ABBaker.h"

int main(int argc, char *argv[])
{
	ABBaker *baker;
#ifndef DEBUG
	LSSharedFileListRef loginItems;
#endif
	
	// Start me up:
    objc_startCollectorThread();
	sleep(1);	// wait a second for the collector thread to come up
	if ([GrowlApplicationBridge isGrowlInstalled])
		[GrowlApplicationBridge setGrowlDelegate:baker];	// initialize Growl
	baker = [[ABBaker alloc] init];
	[[NSGarbageCollector defaultCollector] disableCollectorForPointer:baker];	// don't kill the baker
	if ([[NSProcessInfo processInfo] respondsToSelector:@selector(enableSuddenTermination)])
		[[NSProcessInfo processInfo] performSelector:@selector(enableSuddenTermination)];	// on Snow Leopard & later, let the login window kill us dead when the user wants to log out; we don't care
	
#ifndef DEBUG
	// Add our app to the user's login item list:
	loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, (CFStringRef)[[NSProcessInfo processInfo] processName], NULL, (CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]], NULL, NULL);
	CFRelease(loginItems);
#endif
	
	// Run 'till the cows come home. We don't need no GUI.
	while (1)
	{
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
	}
	return 0;	// UNREACHED
}
