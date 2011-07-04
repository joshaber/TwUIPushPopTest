//
//  PPNavigationController.m
//  PushPopTest
//
//  Created by Josh Abernathy on 7/3/11.
//  Copyright 2011 Maybe Apps, LLC. All rights reserved.
//

#import "PPNavigationController.h"

@interface PPNavigationController ()
@property (nonatomic, retain) NSArray *viewControllers;
@end


@implementation PPNavigationController

- (void)dealloc {
	self.viewControllers = nil;
	
	[super dealloc];
}


#pragma mark TUIResponder

- (void)keyDown:(NSEvent *)event {
	[self.topViewController mouseDown:event];
}


#pragma mark TUIViewController

- (void)loadView {
	[super loadView];
	
	self.view = [[[TUIView alloc] initWithFrame:CGRectZero] autorelease];
	self.view.autoresizingMask = TUIViewAutoresizingFlexibleSize;
	self.view.backgroundColor = [TUIColor blackColor];
}


#pragma mark API

@synthesize viewControllers;

- (id)initWithRootViewController:(TUIViewController *)rootViewController {
	self = [super init];
	if(self == nil) {
		[self release];
		return nil;
	}
	
	self.viewControllers = [NSArray array];
	
	[self pushViewController:rootViewController animated:NO];
	
	return self;
}

- (void)pushViewController:(TUIViewController *)viewController animated:(BOOL)animated {
	TUIViewController *oldTopViewController = self.topViewController;
	
	[oldTopViewController viewWillDisappear:animated];
	[viewController viewWillAppear:animated];
	
	viewController.view.frame = self.view.bounds;
	viewController.parentViewController = self;
	[self.view addSubview:viewController.view];
	
	self.viewControllers = [self.viewControllers arrayByAddingObject:viewController];
	
	void (^completionBlock)(BOOL) = ^(BOOL finished) {
		[oldTopViewController.view removeFromSuperview];
		
		[oldTopViewController viewDidDisappear:animated];
		[viewController viewDidAppear:animated];
	};
	
	if(animated) {
		// We need to force a flush so that the view's frame is set to the far right before we animate it back.
		[CATransaction begin];
		viewController.view.frame = CGRectMake(self.view.bounds.size.width, 0.0f, viewController.view.bounds.size.width, viewController.view.bounds.size.height);
		[CATransaction flush];
		[CATransaction commit];
		
		[TUIView animateWithDuration:0.27f animations:^{
			viewController.view.frame = self.view.bounds;
			oldTopViewController.view.alpha = 0.0f;
		} completion:completionBlock];
	} else {
		completionBlock(YES);
	}
}

- (void)popViewControllerAnimated:(BOOL)animated {
	NSAssert(self.viewControllers.count > 1, @"Trying to pop the root view controller. Ain't gonna happen.");
	
	// we'll release him later on in the completion block
	__block TUIViewController *oldTopViewController = [self.topViewController retain];
	
	NSMutableArray *newViewControllers = [[self.viewControllers mutableCopy] autorelease];
	[newViewControllers removeLastObject];
	self.viewControllers = [[newViewControllers copy] autorelease];
	
	TUIViewController *newTopViewController = self.topViewController;
	
	newTopViewController.view.frame = self.view.bounds;	
	[oldTopViewController viewWillDisappear:animated];
	[newTopViewController viewWillAppear:animated];
	
	[self.view insertSubview:newTopViewController.view belowSubview:oldTopViewController.view];
	
	void (^completionBlock)(BOOL) = ^(BOOL finished) {
		[oldTopViewController.view removeFromSuperview];
		
		[oldTopViewController viewDidDisappear:animated];
		[newTopViewController viewDidAppear:animated];
		
		[oldTopViewController release], oldTopViewController = nil;
	};
	
	if(animated) {
		newTopViewController.view.alpha = 0.0f;
		
		[TUIView animateWithDuration:0.2f animations:^{
			oldTopViewController.view.frame = CGRectMake(self.view.bounds.size.width, 0.0f, oldTopViewController.view.bounds.size.width, oldTopViewController.view.bounds.size.height);
			newTopViewController.view.alpha = 1.0f;
		} completion:completionBlock];
	} else {
		completionBlock(YES);
	}
}

- (TUIViewController *)topViewController {
	return [self.viewControllers lastObject];
}

@end
