/*
 Copyright 2011 Twitter, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this work except in compliance with the License.
 You may obtain a copy of the License in the LICENSE file, or at:
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "TUIKit.h"

#import "TUIScrollKnob.h"
#import "TUIScrollView.h"

@interface TUIScrollKnob ()
- (void)_updateKnob;
- (void)_updateKnobColor:(CGFloat)duration;
@end

@implementation TUIScrollKnob

@synthesize scrollView;
@synthesize knob;

- (id)initWithFrame:(CGRect)frame
{
	if((self = [super initWithFrame:frame]))
	{
		knob = [[TUIView alloc] initWithFrame:CGRectMake(0, 0, 12, 12)];
		knob.layer.cornerRadius = 4.0;
		knob.userInteractionEnabled = NO;
		knob.backgroundColor = [TUIColor blackColor];
		[self addSubview:knob];
		[self _updateKnob];
		[self _updateKnobColor:0.0];
	}
	return self;
}

- (void)dealloc
{
	[knob release];
	[super dealloc];
}

- (BOOL)isVertical
{
	CGRect b = self.bounds;
	return b.size.height > b.size.width;
}

#define KNOB_CALCULATIONS(OFFSET, LENGTH, MIN_KNOB_SIZE) \
float proportion = visible.size.LENGTH / contentSize.LENGTH; \
float knobLength = trackBounds.size.LENGTH * proportion; \
if(knobLength < MIN_KNOB_SIZE) knobLength = MIN_KNOB_SIZE; \
float rangeOfMotion = trackBounds.size.LENGTH - knobLength; \
float maxOffset = contentSize.LENGTH - visible.size.LENGTH; \
float currentOffset = visible.origin.OFFSET; \
float offsetProportion = 1.0 - (maxOffset - currentOffset) / maxOffset; \
float knobOffset = offsetProportion * rangeOfMotion; \
if(isnan(knobOffset)) knobOffset = 0.0; \
if(isnan(knobLength)) knobLength = 0.0;

#define DEFAULT_MIN_KNOB_SIZE 25

- (void)_updateKnob
{
	CGRect trackBounds = self.bounds;
	CGRect visible = scrollView.visibleRect;
	CGSize contentSize = scrollView.contentSize;
	
	if([self isVertical]) {
		KNOB_CALCULATIONS(y, height, DEFAULT_MIN_KNOB_SIZE)
		CGRect frame;
		frame.origin.x = 0.0;
		frame.origin.y = knobOffset;
		frame.size.height = knobLength;
		frame.size.width = trackBounds.size.width;
		
		if(frame.size.height > 2000) {
			frame.size.height = 2000;
		}
		
		knob.frame = ABRectRoundOrigin(CGRectInset(frame, 2, 4));
	} else {
		KNOB_CALCULATIONS(x, width, DEFAULT_MIN_KNOB_SIZE)
		CGRect frame;
		frame.origin.x = knobOffset;
		frame.origin.y = 0.0;
		frame.size.width = knobLength;
		frame.size.height = trackBounds.size.height;
		knob.frame = ABRectRoundOrigin(CGRectInset(frame, 2, 4));
	}
}

- (void)layoutSubviews
{
	[self _updateKnob];
}

- (void)flash
{
	CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
	animation.values = [NSArray arrayWithObjects:
						[NSNumber numberWithDouble:0.5],
						[NSNumber numberWithDouble:0.2],
						[NSNumber numberWithDouble:0.5],
						[NSNumber numberWithDouble:0.2],
						[NSNumber numberWithDouble:0.5],
						nil];
	[knob.layer addAnimation:animation forKey:@"opacity"];
}

- (void)_updateKnobColor:(CGFloat)duration
{
	[TUIView beginAnimations:nil context:NULL];
	[TUIView setAnimationDuration:duration];
	knob.alpha = _scrollKnobFlags.active?0.6:_scrollKnobFlags.hover?0.33:0.18;
	[TUIView commitAnimations];
}

- (void)mouseEntered:(NSEvent *)event
{
	_scrollKnobFlags.hover = 1;
	[self _updateKnobColor:0.08];
}

- (void)mouseExited:(NSEvent *)event
{
	_scrollKnobFlags.hover = 0;
	[self _updateKnobColor:0.25];
}

- (void)mouseDown:(NSEvent *)event
{
	_mouseDown = [self localPointForEvent:event];
	_knobStartFrame = knob.frame;
	_scrollKnobFlags.active = 1;
	[self _updateKnobColor:0.08];

	if([knob pointInside:[self convertPoint:_mouseDown toView:knob] withEvent:event]) { // can't use hitTest because userInteractionEnabled is NO
		// normal drag-knob-scroll
		_scrollKnobFlags.trackingInsideKnob = 1;
	} else {
		// page-scroll
		_scrollKnobFlags.trackingInsideKnob = 0;

		CGRect visible = scrollView.visibleRect;
		CGPoint contentOffset = scrollView.contentOffset;

		if([self isVertical]) {
			if(_mouseDown.y < _knobStartFrame.origin.y) {
				contentOffset.y += visible.size.height;
			} else {
				contentOffset.y -= visible.size.height;
			}
		} else {
			if(_mouseDown.x < _knobStartFrame.origin.x) {
				contentOffset.x += visible.size.width;
			} else {
				contentOffset.x -= visible.size.width;
			}
		}

		[scrollView setContentOffset:contentOffset animated:YES];
	}
}

- (void)mouseUp:(NSEvent *)event
{
	_scrollKnobFlags.active = 0;
	[self _updateKnobColor:0.08];
}

#define KNOB_CALCULATIONS_REVERSE(OFFSET, LENGTH) \
CGRect knobFrame = _knobStartFrame; \
knobFrame.origin.OFFSET += diff.LENGTH; \
CGFloat knobOffset = knobFrame.origin.OFFSET; \
CGFloat minKnobOffset = 0.0; \
CGFloat maxKnobOffset = trackBounds.size.LENGTH - knobFrame.size.LENGTH; \
CGFloat proportion = (knobOffset - 1.0) / (maxKnobOffset - minKnobOffset); \
CGFloat maxContentOffset = contentSize.LENGTH - visible.size.LENGTH;

- (void)mouseDragged:(NSEvent *)event
{
	if(_scrollKnobFlags.trackingInsideKnob) { // normal knob drag
		CGPoint p = [self localPointForEvent:event];
		CGSize diff = CGSizeMake(p.x - _mouseDown.x, p.y - _mouseDown.y);
		
		CGRect trackBounds = self.bounds;
		CGRect visible = scrollView.visibleRect;
		CGSize contentSize = scrollView.contentSize;
		
		if([self isVertical]) {
			KNOB_CALCULATIONS_REVERSE(y, height)
			CGPoint scrollOffset = scrollView.contentOffset;
			scrollOffset.y = roundf(-proportion * maxContentOffset);
			scrollView.contentOffset = scrollOffset;
		} else {
			KNOB_CALCULATIONS_REVERSE(x, width)
			CGPoint scrollOffset = scrollView.contentOffset;
			scrollOffset.x = roundf(-proportion * maxContentOffset);
			scrollView.contentOffset = scrollOffset;
		}
	} else { // dragging in knob-track area
		// ignore
	}
}

@end
