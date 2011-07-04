//
//  PushPopTestAppDelegate.m
//  PushPopTest
//
//  Created by Josh Abernathy on 7/3/11.
//  Copyright 2011 Maybe Apps, LLC. All rights reserved.
//

#import "PushPopTestAppDelegate.h"
#import "PPNavigationController.h"
#import "PPTestViewController1.h"

@interface PushPopTestAppDelegate ()
@property (nonatomic, retain) PPNavigationController *navigationController;
@end


@implementation PushPopTestAppDelegate

- (void)dealloc {
	self.navigationController = nil;
	
	[super dealloc];
}


#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	TUINSView *tuiHost = [[TUINSView alloc] initWithFrame:NSMakeRect(0.0f, 0.0f, self.window.frame.size.width, self.window.frame.size.height)];
	[self.window setContentView:tuiHost];
	
	self.navigationController = [[[PPNavigationController alloc] initWithRootViewController:[[[PPTestViewController1 alloc] init] autorelease]] autorelease];
	tuiHost.rootView = self.navigationController.view;
	
	[self.window makeFirstResponder:tuiHost.rootView];
	[self.window makeKeyAndOrderFront:nil];
	
	[tuiHost release];
}


#pragma mark API

@synthesize window;
@synthesize navigationController;

@end
