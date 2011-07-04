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

#import "TUIScrollView.h"
#import "TUIFastIndexPath.h"

typedef enum {
	TUITableViewStylePlain,              // regular table view
} TUITableViewStyle;

typedef enum {
	TUITableViewScrollPositionNone,        
	TUITableViewScrollPositionTop,    
	TUITableViewScrollPositionMiddle,   
	TUITableViewScrollPositionBottom,
	TUITableViewScrollPositionToVisible, // currently the only supported arg
} TUITableViewScrollPosition;

@class TUITableViewCell;
@protocol TUITableViewDataSource;

@class TUITableView;

@protocol TUITableViewDelegate<NSObject, TUIScrollViewDelegate>

- (CGFloat)tableView:(TUITableView *)tableView heightForRowAtIndexPath:(TUIFastIndexPath *)indexPath;

@optional

- (void)tableView:(TUITableView *)tableView willDisplayCell:(TUITableViewCell *)cell forRowAtIndexPath:(TUIFastIndexPath *)indexPath; // not implemented yet
- (void)tableView:(TUITableView *)tableView didSelectRowAtIndexPath:(TUIFastIndexPath *)indexPath; // happens on mouse down
- (void)tableView:(TUITableView *)tableView didClickRowAtIndexPath:(TUIFastIndexPath *)indexPath withEvent:(NSEvent *)event; // happens on mouse up (can look at clickCount)

@end

@interface TUITableView : TUIScrollView
{
	TUITableViewStyle				 _style;
	id <TUITableViewDataSource>	 _dataSource; // weak
	NSArray							*_sectionInfo;

	TUIView						*_pullDownView;

	CGSize							_lastSize;
	CGFloat							_contentHeight;
	
	NSMutableDictionary				*_visibleItems;
	NSMutableDictionary				*_reusableTableCells;
	
	TUIFastIndexPath				*_selectedIndexPath;
	TUIFastIndexPath				*_indexPathShouldBeFirstResponder;
	NSInteger						_futureMakeFirstResponderToken;
	TUIFastIndexPath				*_keepVisibleIndexPathForReload;
	CGFloat							_relativeOffsetForReload;
	
	struct {
		unsigned int forceSaveScrollPosition:1;
		unsigned int derepeaterEnabled:1;
		unsigned int layoutSubviewsReentrancyGuard:1;
		unsigned int didFirstLayout:1;
		unsigned int dataSourceNumberOfSectionsInTableView:1;
		unsigned int delegateTableViewWillDisplayCellForRowAtIndexPath:1;
	} _tableFlags;
}

- (id)initWithFrame:(CGRect)frame style:(TUITableViewStyle)style;                // must specify style at creation. -initWithFrame: calls this with UITableViewStylePlain

@property (nonatomic,assign) id <TUITableViewDataSource> dataSource;
@property (nonatomic,assign) id <TUITableViewDelegate>   delegate;

- (void)reloadData;

/**
 The table view itself has mechanisms for maintaining scroll position. During a live resize the table view should automatically "do the right thing".  This method may be useful during a reload if you want to stay in the same spot.  Use it instead of -reloadData.
 */
- (void)reloadDataMaintainingVisibleIndexPath:(TUIFastIndexPath *)indexPath relativeOffset:(CGFloat)relativeOffset;

- (NSInteger)numberOfSections;
- (NSInteger)numberOfRowsInSection:(NSInteger)section;

- (CGRect)rectForRowAtIndexPath:(TUIFastIndexPath *)indexPath;

- (TUIFastIndexPath *)indexPathForCell:(TUITableViewCell *)cell;                      // returns nil if cell is not visible
- (NSArray *)indexPathsForRowsInRect:(CGRect)rect;                              // returns nil if rect not valid 

- (TUITableViewCell *)cellForRowAtIndexPath:(TUIFastIndexPath *)indexPath;            // returns nil if cell is not visible or index path is out of range
- (NSArray *)visibleCells; // no particular order
- (NSArray *)sortedVisibleCells; // top to bottom
- (NSArray *)indexPathsForVisibleRows;

- (void)scrollToRowAtIndexPath:(TUIFastIndexPath *)indexPath atScrollPosition:(TUITableViewScrollPosition)scrollPosition animated:(BOOL)animated;

- (TUIFastIndexPath *)indexPathForSelectedRow;                                       // return nil or index path representing section and row of selection.
- (TUIFastIndexPath *)indexPathForFirstRow;
- (TUIFastIndexPath *)indexPathForLastRow;

- (void)selectRowAtIndexPath:(TUIFastIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(TUITableViewScrollPosition)scrollPosition;
- (void)deselectRowAtIndexPath:(TUIFastIndexPath *)indexPath animated:(BOOL)animated;

/**
 Above the top cell, only visible if you pull down (if you have scroll bouncing enabled)
 */
@property (nonatomic, retain) TUIView *pullDownView;

- (BOOL)pullDownViewIsVisible;

/**
 Used by the delegate to acquire an already allocated cell, in lieu of allocating a new one.
 */
- (TUITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier;

@end

@protocol TUITableViewDataSource<NSObject>

@required

- (NSInteger)tableView:(TUITableView *)table numberOfRowsInSection:(NSInteger)section;

- (TUITableViewCell *)tableView:(TUITableView *)tableView cellForRowAtIndexPath:(TUIFastIndexPath *)indexPath;

@optional

/**
 Default is 1 if not implemented
 */
- (NSInteger)numberOfSectionsInTableView:(TUITableView *)tableView;

@end

@interface NSIndexPath (TUITableView)

+ (NSIndexPath *)indexPathForRow:(NSUInteger)row inSection:(NSUInteger)section;

@property(nonatomic,readonly) NSUInteger section;
@property(nonatomic,readonly) NSUInteger row;

@end

#import "TUITableViewCell.h"
#import "TUITableView+Derepeater.h"
