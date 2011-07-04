//
//  PPTestViewController1.m
//  PushPopTest
//
//  Created by Josh Abernathy on 7/3/11.
//  Copyright 2011 Maybe Apps, LLC. All rights reserved.
//

#import "PPTestViewController1.h"
#import "PPNavigationController.h"
#import "PPTestViewController2.h"

@interface PPTestViewController1 ()
@property (nonatomic, retain) TUITextRenderer *textRenderer;
@end


@implementation PPTestViewController1

- (void)dealloc {
	self.textRenderer = nil;
	
	[super dealloc];
}


#pragma mark TUIResponder

- (void)mouseDown:(NSEvent *)event {
	PPNavigationController *navigationController = (PPNavigationController *) self.parentViewController;
	[navigationController pushViewController:[[[PPTestViewController2 alloc] init] autorelease] animated:YES];
}


#pragma mark TUIViewController

- (void)loadView {
	[super loadView];
	
	self.view = [[[TUIView alloc] initWithFrame:CGRectZero] autorelease];
	self.view.autoresizingMask = TUIViewAutoresizingFlexibleSize;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.textRenderer = [[[TUITextRenderer alloc] init] autorelease];
	self.textRenderer.attributedString = [TUIAttributedString stringWithString:@"First View Controller"];
	
	self.view.textRenderers = [NSArray arrayWithObject:self.textRenderer];
	
	__block PPTestViewController1 *blockSelf = self;
	self.view.drawRect = ^(TUIView *blockView, CGRect dirtyRect) {
		[[TUIColor redColor] set];
		CGContextFillRect(TUIGraphicsGetCurrentContext(), blockView.bounds);
		
		[[TUIColor greenColor] set];
		CGContextFillRect(TUIGraphicsGetCurrentContext(), CGRectInset(blockView.bounds, 5.0f, 5.0f));
		
		blockSelf.textRenderer.frame = CGRectMake(20.0f, 50.0f, blockView.bounds.size.width, 15.0f);
		[blockSelf.textRenderer draw];
	};
}


#pragma mark API

@synthesize textRenderer;

@end
