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

@implementation ABBaker

- (id)init
{
	if (self = [super init])
	{
		NSString *dcsNotificationName = [NSString stringWithFormat:@"[DiskCookieStorage %@/Library/Cookies/Cookies.plist]", NSHomeDirectory()];
		
		_database = [[ABTrackerDatabase alloc] init];
		_threadLock = [[NSRecursiveLock alloc] init];
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cookiesDidChange:) name:NSHTTPCookieManagerCookiesChangedNotification object:nil];
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(cookiesDidChange:) name:dcsNotificationName object:nil];
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
