//
//  ABBaker.m
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

#import "ABBaker.h"
#import "ABTrackerDatabase.h"
#import <sys/event.h>

@implementation ABBaker

- (id)init
{
	self = [super init];
	if (self)
	{
		SInt32 osVersion;
		
		Gestalt(gestaltSystemVersion, &osVersion);
		
		_database = [[ABTrackerDatabase alloc] init];
		_threadLock = [[NSRecursiveLock alloc] init];
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cookiesDidChange:) name:NSHTTPCookieManagerCookiesChangedNotification object:nil];
		// Unfortunately the cookies changed notification still doesn't work in Lion (it was broken in Tiger and Leopard as well), so we use a workaround: We watch for changes to the cookies file using kqueue, and when a change occurs, then we perform a cleansing.
		if (osVersion >= 0x1070)
			[NSThread detachNewThreadSelector:@selector(threadedWatchCookies) toTarget:self withObject:nil];
		else
		{
			NSString *dcsNotificationName = [NSString stringWithFormat:@"[DiskCookieStorage %@/Library/Cookies/Cookies.plist]", NSHomeDirectory()];
			
			[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(cookiesDidChange:) name:dcsNotificationName object:nil suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
		}
		[self performSelector:@selector(cookiesDidChange:)];
	}
	return self;
}


- (void)cookiesDidChange:(NSNotification *)aNotification
{
	if ([_threadLock tryLock])	// are we currently doing a cleaning?
	{
		[NSThread detachNewThreadSelector:@selector(threadedTrimCookies) toTarget:self withObject:nil];
		[_threadLock unlock];
	}
	else	// if so, then try again later
		[self performSelector:_cmd withObject:aNotification afterDelay:1.0];
}


- (void)threadedWatchCookies
{
	int kQueue = kqueue();
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSURL *userLibraryURL = [fm URLForDirectory:NSLibraryDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
	NSURL *cookiesURL = [[userLibraryURL URLByAppendingPathComponent:@"Cookies"] URLByAppendingPathComponent:@"Cookies.binarycookies"];
	
	while (1)	// loop forever
	{
		@try
		{
			struct kevent kEvent, theEvent;
			int fd;
			
			do	// we want to watch ~/Library/Cookies/Cookies.binarycookies
			{
				fd = open(cookiesURL.path.fileSystemRepresentation, O_EVTONLY, 0);
			} while (fd == 0);	// keep trying until it works
			
			EV_SET(&kEvent, fd, EVFILT_VNODE, EV_ADD|EV_ENABLE|EV_CLEAR, NOTE_WRITE|NOTE_DELETE, 0, 0);
			kevent(kQueue, &kEvent, 1, NULL, 0, NULL);	// watch for changes to this file
			kevent(kQueue, NULL, 0, &theEvent, 1, NULL);	// block here until a change has been made
			[self cookiesDidChange:nil];	// once a change has been made, let's cleanse it
			close(fd);	// clean up
		}
		@catch (NSException *exception)
		{
			NSLog(@"%@", exception);
		}
	}
}


- (void)threadedTrimCookies
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[_threadLock lock];
#ifdef DEBUG
	NSLog(@"Cleaning cookies started at %@", [NSDate date]);
#endif
	@try
	{
		NSHTTPCookieStorage *cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];
		
		for (NSHTTPCookie *cookie in [[cookieJar cookies] copy])	// work on a copy of the array so we can't be accused of mutating it while iterating through it
		{
			NSString *description;
			
			if ([_database isCookieATrackingCookie:cookie why:&description])
			{
				if ([GrowlApplicationBridge isGrowlRunning])
				{
					if (!description || [description isEqualToString:@""])
						description = NSLocalizedString(@"unknown", @"Description of a cookie whose origins are unknown");
					[GrowlApplicationBridge notifyWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Deleting %@ Cookie", @"Title of Growl notification with the description of the cookie"), description]  description:[NSString stringWithFormat:NSLocalizedString(@"The cookie \\U201C%@\\U201D was set by the Web site \\U201C%@\\U201D and will be deleted on suspicion of being a tracking cookie.", @"Body of Growl notification"), cookie.name, cookie.domain] notificationName:@"CookieDeleted" iconData:nil priority:0 isSticky:NO clickContext:nil];
				}
#ifdef DEBUG
				NSLog(@"Deleting cookie %@", cookie);
#endif
				[cookieJar deleteCookie:cookie];
			}
		}
	}
	@catch (NSException * e)
	{
		NSLog(@"%@", e);
	}
	@finally
	{
#ifdef DEBUG
		NSLog(@"Cleaning cookies ended at %@", [NSDate date]);
#endif
		[_threadLock unlock];
		[pool drain];
	}
}

@end
