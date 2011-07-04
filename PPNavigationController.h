//
//  PPNavigationController.h
//  PushPopTest
//
//  Created by Josh Abernathy on 7/3/11.
//  Copyright 2011 Maybe Apps, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PPNavigationController : TUIViewController {}

- (id)initWithRootViewController:(TUIViewController *)rootViewController;

- (void)pushViewController:(TUIViewController *)viewController animated:(BOOL)animated;
- (void)popViewControllerAnimated:(BOOL)animated;

@property (nonatomic, readonly) TUIViewController *topViewController;
@property (nonatomic, readonly, retain) NSArray *viewControllers;

@end
