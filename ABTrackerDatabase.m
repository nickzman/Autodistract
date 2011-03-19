//
//  ABTrackerDatabase.m
//  Autodistract
//
//  Created by Nick Zitzmann on 3/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ABTrackerDatabase.h"

@implementation ABTrackerDatabase

- (id)init
{
	if (self = [super init])
	{
		FSRef appSupportFSRef;
		BOOL needsDownload = NO;
		
		if (FSFindFolder(kUserDomain, kApplicationSupportFolderType, true, &appSupportFSRef) == noErr)	// get the user's application support folder; unless something stupendous happens this should always work
		{
			NSURL *appSupportFolderURL = (NSURL *)CFURLCreateFromFSRef(NULL, &appSupportFSRef);
			NSString *abSupportFolder = [appSupportFolderURL.path stringByAppendingPathComponent:@"Autodistract"];
			NSString *pathToSignatureFile = [abSupportFolder stringByAppendingPathComponent:@"TrackingCookieSigs.plist"];
			
			NSMakeCollectable(appSupportFolderURL);
			if (![[NSFileManager defaultManager] fileExistsAtPath:pathToSignatureFile])	// if the signature file doesn't exist, then we need to download it
				needsDownload = YES;
			else
			{
				NSDate *modDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:pathToSignatureFile error:NULL] fileModificationDate];
				
				if (CFAbsoluteTimeGetCurrent()-modDate.timeIntervalSinceReferenceDate > 604800.0)	// if it's been a week since we last updated the signature file, then let's update it again
					needsDownload = YES;
			}
			
			if (needsDownload)
			{
				_signatures = [NSArray arrayWithContentsOfURL:[NSURL URLWithString:@"http://seiryu.home.comcast.net/TrackingCookieSigs.plist"]];	// start downloading
				if (_signatures)	// if we got it, then write it to disk
				{
					if (![[NSFileManager defaultManager] fileExistsAtPath:abSupportFolder])
						[[NSFileManager defaultManager] createDirectoryAtPath:abSupportFolder withIntermediateDirectories:YES attributes:nil error:NULL];
					[_signatures writeToFile:pathToSignatureFile atomically:YES];
				}
			}
			else
			{
				_signatures = [NSArray arrayWithContentsOfFile:pathToSignatureFile];
			}
		}
		
		if (!_signatures)	// if we couldn't find it on the disk or on the 'net, then fall back on the signature file of last resort, which is in our bundle
			_signatures = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"TrackingCookieSigs" ofType:@"plist"]];
	}
	return self;
}


- (BOOL)isCookieATrackingCookie:(NSHTTPCookie *)cookie why:(NSString **)description
{
	NSString *cookieName = [cookie name];
	NSString *cookieDomain = [cookie domain];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(%K == YES AND %@ BEGINSWITH %K) OR (%K == NO AND %K == %@) OR %@ ENDSWITH %K", @"CookieNameBeginsWith", cookieName, @"CookieName", @"CookieNameBeginsWith", @"CookieName", cookieName, cookieDomain, @"CookieDomain"];
	NSArray *matchingSigs = [_signatures filteredArrayUsingPredicate:predicate];
	
	if (matchingSigs && matchingSigs.count)
	{
		if (description)
		{
			NSDictionary *sig = [matchingSigs objectAtIndex:0UL];
			
			*description = [sig objectForKey:@"UserReadableDescription"];
		}
		return YES;
	}
	return NO;
}

@end
