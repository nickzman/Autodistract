//
//  ABBaker.m
//  Autobake
//
//  Created by Nick Zitzmann on 3/13/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ABBaker.h"

void RemoveCookies(id <NSFastEnumeration> cookies, id observer)
{
	NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	
#ifdef DEBUG
	NSLog(@"Removing %ld cookies", [(id)cookies count]);
#endif
	//[[NSNotificationCenter defaultCenter] removeObserver:observer name:NSHTTPCookieManagerCookiesChangedNotification object:nil];
	for (NSHTTPCookie *cookie in cookies)
	{
		if ([GrowlApplicationBridge isGrowlRunning])
			[GrowlApplicationBridge notifyWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Deleting Cookie \\U201C%@\\U201D", @"Title of Growl notification"), cookie.name]  description:[NSString stringWithFormat:NSLocalizedString(@"The cookie \\U201C%@\\U201D was set by the Web site \\U201C%@\\U201D and will be deleted on suspicion of being a tracking cookie.", @"Body of Growl notification"), cookie.name, cookie.domain] notificationName:@"CookieDeleted" iconData:nil priority:0 isSticky:NO clickContext:nil];
		[storage deleteCookie:cookie];
	}
	//[[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(cookiesDidChange:) name:NSHTTPCookieManagerCookiesChangedNotification object:nil];
}


NSSet *SuspectedTrackingCookies(void)
{
	NSMutableSet *trackingCookies = [NSMutableSet set];
	
	for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies])
	{
		NSString *name = cookie.name;
		
		if (![cookie isSessionOnly] &&
			([name isEqualToString:@"__csv"] ||
			 [name hasPrefix:@"__g_"] ||                     // Google Analytics?
			 [name isEqualToString:@"__gads"] ||
			 [name isEqualToString:@"__qca"] ||
			 [name isEqualToString:@"__unam"] ||             // Google Analytics
			 [name hasPrefix:@"__utm"] ||                    // Google Analytics
			 [name isEqualToString:@"_br_uid_1"] ||
			 [name isEqualToString:@"_chartbeat2"] ||
			 [name isEqualToString:@"_jsuid"] ||
			 [name isEqualToString:@".ASPXANONYMOUS"] ||
			 [name isEqualToString:@"ACOOKIE"] ||
			 [name isEqualToString:@"alpha"] ||
			 [name isEqualToString:@"anonId"] ||
			 [name isEqualToString:@"BBC-UID"] ||			// BBC
			 [name hasPrefix:@"BIMREG"] ||
			 [name isEqualToString:@"CNNid"] ||				// CNN
			 [name isEqualToString:@"DMUserTrack"] ||
			 [name isEqualToString:@"EkAnalytics"] ||
			 [name isEqualToString:@"EktGUID"] ||
			 [name hasPrefix:@"exp_last"] ||
			 [name isEqualToString:@"FarkUser"] ||			// Fark.com
			 [name hasPrefix:@"fpc1000"] ||
			 [name isEqualToString:@"FTUserTrack"] ||
			 [name isEqualToString:@"GCIONID"] ||
			 [name isEqualToString:@"GTC"] ||
			 [name isEqualToString:@"guest_id"] ||
			 [name hasPrefix:@"GUID"] ||
			 [name hasPrefix:@"km_"] ||
			 [name hasPrefix:@"MintUnique"] ||
			 [name isEqualToString:@"NGUserID"] ||
			 [name isEqualToString:@"NID"] ||				// Google
			 [name hasPrefix:@"OA"] ||
			 [name hasPrefix:@"PBCS"] ||
			 [name hasPrefix:@"PD_poll"] ||
			 [name isEqualToString:@"RES_TRACKINGID"] ||
			 [name hasPrefix:@"s_"] ||
			 [name isEqualToString:@"scorecardresearch"] ||  // Scorecard Research
			 [name hasPrefix:@"SESSID"] ||
			 [name isEqualToString:@"track"] ||
			 [name isEqualToString:@"UNAUTHID"] ||
			 [name isEqualToString:@"uuid"] ||
			 [name hasPrefix:@"visitor_id"] ||
			 [name isEqualToString:@"welcome"] ||
			 [name isEqualToString:@"wooTracker"] ||
			 [name isEqualToString:@"WT_FPC"]))
			[trackingCookies addObject:cookie];
	}
	return trackingCookies;
}

@implementation ABBaker

- (id)init
{
	if (self = [super init])
	{
		NSString *dcsNotificationName = [NSString stringWithFormat:@"[DiskCookieStorage %@/Library/Cookies/Cookies.plist]", NSHomeDirectory()];
		
		
		_threadLock = [[NSRecursiveLock alloc] init];
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cookiesDidChange:) name:NSHTTPCookieManagerCookiesChangedNotification object:nil];
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(cookiesDidChange:) name:dcsNotificationName object:nil];
		[self performSelector:@selector(cookiesDidChange:)];
	}
	return self;
}


- (void)cookiesDidChange:(NSNotification *)aNotification
{
	if ([_threadLock tryLock])
	{
		[NSThread detachNewThreadSelector:@selector(threadedTrimCookies) toTarget:self withObject:nil];
		[_threadLock unlock];
	}
}


- (void)threadedTrimCookies
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[_threadLock lock];
#ifdef DEBUG
	NSLog(@"Cleaning cookies");
#endif
	@try
	{
		NSSet *trackingCookies = SuspectedTrackingCookies();
		
		RemoveCookies(trackingCookies, self);
	}
	@catch (NSException * e)
	{
		NSLog(@"%@", e);
	}
	@finally
	{
		[_threadLock unlock];
		[pool drain];
	}
}

@end
