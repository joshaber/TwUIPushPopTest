//
//  PPTestViewController2.m
//  PushPopTest
//
//  Created by Josh Abernathy on 7/3/11.
//  Copyright 2011 Maybe Apps, LLC. All rights reserved.
//

#import "PPTestViewController2.h"
#import "PPNavigationController.h"

@interface PPTestViewController2 ()
@property (nonatomic, retain) TUITextRenderer *textRenderer;
@end


@implementation PPTestViewController2

- (void)dealloc {
	self.textRenderer = nil;
	
	[super dealloc];
}


#pragma mark TUIResponder

- (void)mouseDown:(NSEvent *)event {
	PPNavigationController *navigationController = (PPNavigationController *) self.parentViewController;
	[navigationController popViewControllerAnimated:YES];
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
	TUIAttributedString *attributedString = [TUIAttributedString stringWithString:@"Second View Controller. Press any key to pop this view controller."];
	[attributedString setFont:[TUIFont fontWithName:@"HelveticaNeue" size:15.0f]];
	self.textRenderer.attributedString = attributedString;
	
	self.view.textRenderers = [NSArray arrayWithObject:self.textRenderer];
	
	__block PPTestViewController2 *blockSelf = self;
	self.view.drawRect = ^(TUIView *blockView, CGRect dirtyRect) {
		[[TUIColor greenColor] set];
		CGContextFillRect(TUIGraphicsGetCurrentContext(), blockView.bounds);
		
		[[TUIColor redColor] set];
		CGContextFillRect(TUIGraphicsGetCurrentContext(), CGRectInset(blockView.bounds, 5.0f, 5.0f));
		
		blockSelf.textRenderer.frame = CGRectMake(20.0f, 50.0f, blockView.bounds.size.width, 30.0f);
		[blockSelf.textRenderer draw];
	};
}


#pragma mark API

@synthesize textRenderer;

@end
