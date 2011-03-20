//
//  main.m
//  Autodistract
//
//  Created by Nick Zitzmann on 3/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
		[[NSRunLoop currentRunLoop] run];
	}
	return 0;	// UNREACHED
}
