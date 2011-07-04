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

#import "TUITableView.h"
#import "TUINSView.h"

typedef struct {
	CGFloat offset; // from beginning of section
	CGFloat height;
} TUITableViewRowInfo;

@interface TUITableViewSection : NSObject
{
	TUITableView *_tableView; // weak
	NSInteger sectionIndex;
	NSUInteger numberOfRows;
	CGFloat sectionHeight;
	CGFloat sectionOffset;
	TUITableViewRowInfo *rowInfo;
}

@property (nonatomic, assign) CGFloat sectionOffset;

@end

@implementation TUITableViewSection

@synthesize sectionOffset;

- (id)initWithNumberOfRows:(NSUInteger)n sectionIndex:(NSInteger)s tableView:(TUITableView *)t
{
	if((self = [super init]))
	{
		_tableView = t;
		sectionIndex = s;
		numberOfRows = n;
		rowInfo = calloc(n, sizeof(TUITableViewRowInfo));
	}
	return self;
}

- (void)dealloc
{
	free(rowInfo);
	[super dealloc];
}

- (NSUInteger)numberOfRows
{
	return numberOfRows;
}

- (void)_setupRowHeights
{
	int i;
	sectionHeight = 0.0;
	for(i = 0; i < numberOfRows; ++i) {
		CGFloat h = roundf([_tableView.delegate tableView:_tableView heightForRowAtIndexPath:[TUIFastIndexPath indexPathForRow:i inSection:sectionIndex]]);
		rowInfo[i].offset = sectionHeight;
		rowInfo[i].height = h;
		sectionHeight += h;
	}
}

- (CGFloat)rowHeight:(NSInteger)i
{
	if(i >= 0 && i < numberOfRows)
		return rowInfo[i].height;
	return 0.0;
}

- (CGFloat)sectionRowOffset:(NSInteger)i
{
	if(i >= 0 && i < numberOfRows)
		return rowInfo[i].offset;
	return 0.0;
}

- (CGFloat)tableRowOffset:(NSInteger)i
{
	return sectionOffset + [self sectionRowOffset:i];
}

- (CGFloat)sectionHeight
{
	return sectionHeight;
}

@end



@interface TUITableView (Private)
- (void)_updateDerepeaterViews;
@end

@implementation TUITableView

@synthesize pullDownView=_pullDownView;

- (id)initWithFrame:(CGRect)frame style:(TUITableViewStyle)style
{
	if((self = [super initWithFrame:frame])) {
		_style = style;
		_reusableTableCells = [[NSMutableDictionary alloc] init];
		_visibleItems = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (id)initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame style:TUITableViewStylePlain];
}

- (void)dealloc
{
	[_sectionInfo release];
	[_visibleItems release];
	[_reusableTableCells release];
	[_selectedIndexPath release];
	[_indexPathShouldBeFirstResponder release];
	[_keepVisibleIndexPathForReload release];
	[_pullDownView release];
	[super dealloc];
}

- (id<TUITableViewDelegate>)delegate
{
	return (id<TUITableViewDelegate>)[super delegate];
}

- (void)setDelegate:(id<TUITableViewDelegate>)d
{
	_tableFlags.delegateTableViewWillDisplayCellForRowAtIndexPath = [d respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)];
	[super setDelegate:d]; // must call super
}

- (id<TUITableViewDataSource>)dataSource
{
	return _dataSource;
}

- (void)setDataSource:(id<TUITableViewDataSource>)d
{
	_dataSource = d;
	_tableFlags.dataSourceNumberOfSectionsInTableView = [_dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)];
}

- (NSInteger)numberOfSections
{
	return [_sectionInfo count];
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section
{
	return [[_sectionInfo objectAtIndex:section] numberOfRows];
}

- (CGRect)rectForRowAtIndexPath:(TUIFastIndexPath *)indexPath
{
	NSInteger section = indexPath.section;
	NSInteger row = indexPath.row;
	if(section >= 0 && section < [_sectionInfo count]) {
		TUITableViewSection *s = [_sectionInfo objectAtIndex:section];
		CGFloat offset = [s tableRowOffset:row];
		CGFloat height = [s rowHeight:row];
		CGFloat y = _contentHeight - offset - height;
		return CGRectMake(0, y, self.bounds.size.width, height);
	}
	return CGRectZero;
}






- (NSArray *)_freshSectionInfo
{
	NSInteger numberOfSections = 1;
	if(_tableFlags.dataSourceNumberOfSectionsInTableView)
		numberOfSections = [_dataSource numberOfSectionsInTableView:self];
	
	NSMutableArray *sections = [NSMutableArray arrayWithCapacity:numberOfSections];
	
	int s;
	CGFloat offset = 0.0;
	for(s = 0; s < numberOfSections; ++s) {
		TUITableViewSection *section = [[TUITableViewSection alloc] initWithNumberOfRows:[_dataSource tableView:self numberOfRowsInSection:s] sectionIndex:s tableView:self];
		[section _setupRowHeights];
		section.sectionOffset = offset;
		offset += [section sectionHeight];
		[sections addObject:section];
		[section release];
	}
	
	_contentHeight = offset;
	
	return sections;
}

- (void)_enqueueReusableCell:(TUITableViewCell *)cell
{
	NSString *identifier = cell.reuseIdentifier;
	
	if(!identifier)
		return;
	
	NSMutableArray *array = [_reusableTableCells objectForKey:identifier];
	if(!array) {
		array = [[NSMutableArray alloc] init];
		[_reusableTableCells setObject:array forKey:identifier];
		[array release];
	}
	[array addObject:cell];
}

- (TUITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier
{
	if(!identifier)
		return nil;
	
	NSMutableArray *array = [_reusableTableCells objectForKey:identifier];
	if(array) {
		TUITableViewCell *c = [array lastObject];
		if(c) {
			[c retain];
			[array removeLastObject];
			[c prepareForReuse];
			return [c autorelease];
		}
	}
	return nil;
}

- (TUITableViewCell *)cellForRowAtIndexPath:(TUIFastIndexPath *)indexPath // returns nil if cell is not visible or index path is out of range
{
	return [_visibleItems objectForKey:indexPath];
}

- (NSArray *)visibleCells
{
	return [_visibleItems allValues];
}

static NSInteger SortCells(TUITableViewCell *a, TUITableViewCell *b, void *ctx)
{
	if(a.frame.origin.y > b.frame.origin.y)
		return NSOrderedAscending;
	return NSOrderedDescending;
}

- (NSArray *)sortedVisibleCells
{
	NSArray *v = [self visibleCells];
	return [v sortedArrayUsingComparator:(NSComparator)^NSComparisonResult(TUITableViewCell *a, TUITableViewCell *b) {
		if(a.frame.origin.y > b.frame.origin.y)
			return NSOrderedAscending;
		return NSOrderedDescending;
	}];
}

#define INDEX_PATHS_FOR_VISIBLE_ROWS [_visibleItems allKeys]

- (NSArray *)indexPathsForVisibleRows
{
	return INDEX_PATHS_FOR_VISIBLE_ROWS;
}

- (TUIFastIndexPath *)indexPathForCell:(TUITableViewCell *)c
{
	for(TUIFastIndexPath *i in _visibleItems) {
		TUITableViewCell *cell = [_visibleItems objectForKey:i];
		if(cell == c)
			return i;
	}
	return nil;
}

- (NSArray *)indexPathsForRowsInRect:(CGRect)rect
{
	NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:50];
	NSInteger sectionIndex = 0;
	for(TUITableViewSection *section in _sectionInfo) {
		NSInteger numberOfRows = [section numberOfRows];
		for(NSInteger row = 0; row < numberOfRows; ++row) {
			TUIFastIndexPath *indexPath = [TUIFastIndexPath indexPathForRow:row inSection:sectionIndex];
			CGRect cellRect = [self rectForRowAtIndexPath:indexPath];
			if(CGRectIntersectsRect(cellRect, rect)) {
				[indexPaths addObject:indexPath];
			} else {
				// not visible
			}
		}
		++sectionIndex;
	}
	return indexPaths;
}

- (TUIFastIndexPath *)_topVisibleIndexPath
{
	TUIFastIndexPath *topVisibleIndex = nil;
	NSArray *v = [INDEX_PATHS_FOR_VISIBLE_ROWS sortedArrayUsingSelector:@selector(compare:)];
	if([v count])
		topVisibleIndex = [v objectAtIndex:0];
	return topVisibleIndex;
}

- (void)setFrame:(CGRect)f
{
	_tableFlags.forceSaveScrollPosition = 1;
	[super setFrame:f];
}

- (void)setContentOffset:(CGPoint)p
{
	_tableFlags.didFirstLayout = 1; // prevent the auto-scroll-to-top during the first layout
	[super setContentOffset:p];
}

- (void)setPullDownView:(TUIView *)p
{
	[_pullDownView removeFromSuperview];
	
	[p retain];
	[_pullDownView release];
	_pullDownView = p;
	
	[self addSubview:_pullDownView];
	_pullDownView.hidden = YES;
}

- (BOOL)_preLayoutCells
{
	CGRect bounds = self.bounds;

	if(!_sectionInfo || !CGSizeEqualToSize(bounds.size, _lastSize)) {
		
		// save scroll position
		TUIFastIndexPath *savedIndexPath = nil;
		CGFloat relativeOffset = 0.0;
		if(_tableFlags.forceSaveScrollPosition || [self.nsView inLiveResize]) {
			_tableFlags.forceSaveScrollPosition = 0;
			NSArray *a = [INDEX_PATHS_FOR_VISIBLE_ROWS sortedArrayUsingSelector:@selector(compare:)];
			if([a count]) {
				savedIndexPath = [[a objectAtIndex:0] retain];
				CGRect v = [self visibleRect];
				CGRect r = [self rectForRowAtIndexPath:savedIndexPath];
				relativeOffset = ((v.origin.y + v.size.height) - (r.origin.y + r.size.height));
				relativeOffset += (_lastSize.height - bounds.size.height);
			}
		} else if(_keepVisibleIndexPathForReload) {
			savedIndexPath = [_keepVisibleIndexPathForReload retain];
			relativeOffset = _relativeOffsetForReload;
			[_keepVisibleIndexPathForReload release];
			_keepVisibleIndexPathForReload = nil;
		}
		
		[_sectionInfo release];
		_sectionInfo = [[self _freshSectionInfo] retain]; // calculates new contentHeight here
		self.contentSize = CGSizeMake(self.bounds.size.width, _contentHeight);
		
		_lastSize = bounds.size;
		
		if(!_tableFlags.didFirstLayout) {
			_tableFlags.didFirstLayout = 1;
			[self scrollToTopAnimated:NO];
		}
		
		// restore scroll position
		if(savedIndexPath) {
			CGRect v = [self visibleRect];
			CGRect r = [self rectForRowAtIndexPath:savedIndexPath];
			r.origin.y -= (v.size.height - r.size.height);
			r.size.height += (v.size.height - r.size.height);
			
			r.origin.y += relativeOffset;
			
			[self scrollRectToVisible:r animated:NO];
			[savedIndexPath release];
		}
		
		return YES; // needs visible cells to be redisplayed
	}
	
	return NO; // just need to do the recycling
}

- (void)_layoutCells:(BOOL)visibleCellsNeedRelayout
{
	if(visibleCellsNeedRelayout) {
		// update remaining visible cells if needed
		for(TUIFastIndexPath *i in _visibleItems) {
			TUITableViewCell *cell = [_visibleItems objectForKey:i];
			cell.frame = [self rectForRowAtIndexPath:i];
			[cell setNeedsLayout];
		}
	}
	
	CGRect visible = [self visibleRect];
	
	// Example:
	// old:            0 1 2 3 4 5 6 7
	// new:                2 3 4 5 6 7 8 9
	// to remove:      0 1
	// to add:                         8 9
	
	NSArray *oldVisibleIndexPaths = INDEX_PATHS_FOR_VISIBLE_ROWS;
	NSArray *newVisibleIndexPaths = [self indexPathsForRowsInRect:visible];
	
	NSMutableArray *indexPathsToRemove = [[oldVisibleIndexPaths mutableCopy] autorelease];
	[indexPathsToRemove removeObjectsInArray:newVisibleIndexPaths];
	
	NSMutableArray *indexPathsToAdd = [[newVisibleIndexPaths mutableCopy] autorelease];
	[indexPathsToAdd removeObjectsInArray:oldVisibleIndexPaths];
	
	// remove offscreen cells
	for(TUIFastIndexPath *i in indexPathsToRemove) {
		TUITableViewCell *cell = [self cellForRowAtIndexPath:i];
		[self _enqueueReusableCell:cell];
		[cell removeFromSuperview];
		[_visibleItems removeObjectForKey:i];
	}
	
	// add new cells
	for(TUIFastIndexPath *i in indexPathsToAdd) {
		if([_visibleItems objectForKey:i]) {
			NSLog(@"!!! Warning: already have a cell in place for index path %@\n\n\n", i);
		} else {
			TUITableViewCell *cell = [_dataSource tableView:self cellForRowAtIndexPath:i];
			[self.nsView invalidateHoverForView:cell];
			cell.frame = [self rectForRowAtIndexPath:i];
			[cell setNeedsLayout];
			[cell prepareForDisplay];
			if([i isEqual:_selectedIndexPath]) {
				[cell setSelected:YES animated:NO];
			} else {
				[cell setSelected:NO animated:NO];
			}
			[self addSubview:cell];
			if([_indexPathShouldBeFirstResponder isEqual:i]) {
				[self.nsWindow makeFirstResponderIfNotAlreadyInResponderChain:cell withFutureRequestToken:_futureMakeFirstResponderToken];
				[_indexPathShouldBeFirstResponder release];
				_indexPathShouldBeFirstResponder = nil;
			}
			[_visibleItems setObject:cell forKey:i];
		}
	}
	
	if(_pullDownView) {
		CGSize s = self.contentSize;
		CGRect pullDownRect = CGRectMake(0, s.height, visible.size.width, _pullDownView.frame.size.height);
		if([self pullDownViewIsVisible]) {
			if(_pullDownView.hidden) {
				// show
				_pullDownView.frame = pullDownRect;
				_pullDownView.hidden = NO;
			}
		} else {
			if(!_pullDownView.hidden) {
				_pullDownView.hidden = YES;
			}
		}
	}
}

- (BOOL)pullDownViewIsVisible
{
	if(_pullDownView) {
		CGSize s = self.contentSize;
		CGRect visible = [self visibleRect];
		CGRect pullDownRect = CGRectMake(0, s.height, visible.size.width, _pullDownView.frame.size.height);
		return CGRectIntersectsRect(pullDownRect, visible);
	}
	return NO;
}

- (void)reloadDataMaintainingVisibleIndexPath:(TUIFastIndexPath *)indexPath relativeOffset:(CGFloat)relativeOffset
{
	[_keepVisibleIndexPathForReload release];
	_keepVisibleIndexPathForReload = [indexPath retain];
	_relativeOffsetForReload = relativeOffset;
	[self reloadData];
}

- (void)reloadData
{
	// need to recycle all visible cells, have them be regenerated on layoutSubviews
	// because the same cells might have different content
	for(TUIFastIndexPath *i in _visibleItems) {
		TUITableViewCell *cell = [_visibleItems objectForKey:i];
		[self _enqueueReusableCell:cell];
		[cell removeFromSuperview];
	}
	[_visibleItems removeAllObjects];
	
	[_sectionInfo release];
	_sectionInfo = nil; // will be regenerated on next layout
	
	[self layoutSubviews];
}

- (void)layoutSubviews
{
	if(!_tableFlags.layoutSubviewsReentrancyGuard) {
		_tableFlags.layoutSubviewsReentrancyGuard = 1;
		
		[TUIView setAnimationsEnabled:NO block:^{
			[CATransaction begin];
			[CATransaction setDisableActions:YES];
			
			BOOL visibleCellsNeedRelayout = [self _preLayoutCells];
			[super layoutSubviews]; // this will munge with the contentOffset
			[self _layoutCells:visibleCellsNeedRelayout];
			
			if(_tableFlags.derepeaterEnabled)
				[self _updateDerepeaterViews];
			
			[CATransaction commit];
		}];
		
		_tableFlags.layoutSubviewsReentrancyGuard = 0;
	} else {
//		NSLog(@"trying to nest...");
	}
}

- (void)scrollToRowAtIndexPath:(TUIFastIndexPath *)indexPath atScrollPosition:(TUITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
	CGRect v = [self visibleRect];
	CGRect r = [self rectForRowAtIndexPath:indexPath];
	switch(scrollPosition) {
		case TUITableViewScrollPositionNone:
			// do nothing
			break;
		case TUITableViewScrollPositionTop:
			r.origin.y -= (v.size.height - r.size.height);
			r.size.height += (v.size.height - r.size.height);
			[self scrollRectToVisible:r animated:animated];
			break;
		case TUITableViewScrollPositionToVisible:
		default:
			[self scrollRectToVisible:r animated:animated];
			break;
		
	}
}

- (TUIFastIndexPath *)indexPathForSelectedRow
{
	return _selectedIndexPath;
}

- (TUIFastIndexPath *)indexPathForFirstRow
{
	return [TUIFastIndexPath indexPathForRow:0 inSection:0];
}

- (TUIFastIndexPath *)indexPathForLastRow
{
	NSInteger sec = [self numberOfSections] - 1;
	NSInteger row = [self numberOfRowsInSection:sec] - 1;
	return [TUIFastIndexPath indexPathForRow:row inSection:sec];
}

- (void)_makeRowAtIndexPathFirstResponder:(TUIFastIndexPath *)indexPath
{
	TUITableViewCell *cell = [self cellForRowAtIndexPath:indexPath];
	if(cell) {
		[self.nsWindow makeFirstResponderIfNotAlreadyInResponderChain:cell];
	} else {
		[_indexPathShouldBeFirstResponder release];
		_indexPathShouldBeFirstResponder = [indexPath retain];
		_futureMakeFirstResponderToken = [self.nsWindow futureMakeFirstResponderRequestToken];
	}
}

- (void)selectRowAtIndexPath:(TUIFastIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(TUITableViewScrollPosition)scrollPosition
{
	if([indexPath isEqual:[self indexPathForSelectedRow]]) {
		// just scroll to visible
	} else {
		[self deselectRowAtIndexPath:[self indexPathForSelectedRow] animated:animated];
		TUITableViewCell *cell = [self cellForRowAtIndexPath:indexPath]; // may be nil
		[cell setSelected:YES animated:animated];
		[_selectedIndexPath release]; // should already be nil
		_selectedIndexPath = [indexPath retain];
		[cell setNeedsDisplay];
	}
	[self _makeRowAtIndexPathFirstResponder:indexPath];
	[self scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
}

- (void)deselectRowAtIndexPath:(TUIFastIndexPath *)indexPath animated:(BOOL)animated
{
	if([indexPath isEqual:_selectedIndexPath]) {
		TUITableViewCell *cell = [self cellForRowAtIndexPath:indexPath]; // may be nil
		[cell setSelected:NO animated:animated];
		[_selectedIndexPath release];
		_selectedIndexPath = nil;
		[cell setNeedsDisplay];
	}
}

- (TUIFastIndexPath *)indexPathForFirstVisibleRow 
{
	TUIFastIndexPath *firstIndexPath = nil;
	for(TUIFastIndexPath *indexPath in _visibleItems) {
		if(firstIndexPath == nil || [indexPath compare:firstIndexPath] == NSOrderedAscending) {
			firstIndexPath = indexPath;
		}
	}
	return firstIndexPath;
}

- (TUIFastIndexPath *)indexPathForLastVisibleRow 
{
	TUIFastIndexPath *lastIndexPath = nil;
	for(TUIFastIndexPath *indexPath in _visibleItems) {
		if(lastIndexPath == nil || [indexPath compare:lastIndexPath] == NSOrderedDescending) {
			lastIndexPath = indexPath;
		}
	}
	return lastIndexPath;
}

- (BOOL)performKeyAction:(NSEvent *)event
{
	// no selection or selected cell not visible and this is not repeative key press
	BOOL noCurrentSelection = (_selectedIndexPath == nil || ([self cellForRowAtIndexPath:_selectedIndexPath] == nil && ![event isARepeat]));;
	
	switch([[event charactersIgnoringModifiers] characterAtIndex:0]) {
		case NSUpArrowFunctionKey: {
			TUIFastIndexPath *newIndexPath;
			if(noCurrentSelection) {
				newIndexPath = [self indexPathForLastVisibleRow];
			} else {
				NSUInteger section = _selectedIndexPath.section;
				NSUInteger row = _selectedIndexPath.row;
				if(row > 0) {
					row--;
				} else {
					while(section > 0) {
						section--;
						NSUInteger rowsInSection = [self numberOfRowsInSection:section];
						if(rowsInSection > 0) {
							row = rowsInSection - 1;
							break;
						}
					}
				}
				newIndexPath = [TUIFastIndexPath indexPathForRow:row inSection:section];
			}
			
			[self selectRowAtIndexPath:newIndexPath animated:YES scrollPosition:TUITableViewScrollPositionToVisible];
			return YES;
		}
	
		case NSDownArrowFunctionKey:  {
			TUIFastIndexPath *newIndexPath;
			if(noCurrentSelection) {
				newIndexPath = [self indexPathForFirstVisibleRow]; 
			} else {
				NSUInteger section = _selectedIndexPath.section;
				NSUInteger row = _selectedIndexPath.row;
				NSUInteger rowsInSection = [self numberOfRowsInSection:section];
				if(row + 1 < rowsInSection) {
					row++;
				} else {
					NSUInteger sections = [self numberOfSections];
					while(section + 1 < sections) {
						section++;
						NSUInteger rowsInSection = [self numberOfRowsInSection:section];
						if(rowsInSection > 0) {
							row = 0;
							break;
						}
					}
				}
				newIndexPath = [TUIFastIndexPath indexPathForRow:row inSection:section];
			}
			
			[self selectRowAtIndexPath:newIndexPath animated:YES scrollPosition:TUITableViewScrollPositionToVisible];
			return YES;
		}
	}
	
	return [super performKeyAction:event];
}

@end


@implementation NSIndexPath (TUITableView)

+ (NSIndexPath *)indexPathForRow:(NSUInteger)row inSection:(NSUInteger)section
{
	NSUInteger i[] = {section, row};
	return [NSIndexPath indexPathWithIndexes:i length:2];
}

- (NSUInteger)section
{
	return [self indexAtPosition:0];
}

- (NSUInteger)row
{
	return [self indexAtPosition:1];
}

@end
