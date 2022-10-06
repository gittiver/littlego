// -----------------------------------------------------------------------------
// Copyright 2022 Patrick Näf (herzbube@herzbube.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// -----------------------------------------------------------------------------


// Project includes
#import "NodeNumbersTileView.h"
#import "layer/DummyLayerDelegate.h"
#import "../model/NodeTreeViewMetrics.h"
#import "../../go/GoGame.h"
#import "../../main/ApplicationDelegate.h"
#import "../../shared/LongRunningActionCounter.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for NodeNumbersTileView.
// -----------------------------------------------------------------------------
@interface NodeNumbersTileView()
/// @brief Prevents double-unregistering of notification responders by
/// willMoveToSuperview: followed by dealloc, or double-registering by two
/// consecutive invocations of willMoveToSuperview: where the argument is not
/// nil.
///
/// With the current tiling implementation these precautions are probably
/// unnecessary because the two scenarios should never occur. The keyword is
/// "should" - we are not entirely sure how things might behave in production,
/// so we are playing it safe. Also, we guard against future implementation
/// changes.
@property(nonatomic, assign) bool notificationRespondersAreSetup;
@property(nonatomic, retain) DummyLayerDelegate* dummyLayerDelegate;
@property(nonatomic, assign) bool drawLayerWasDelayed;
@end


@implementation NodeNumbersTileView

#pragma mark - Synthesize properties

// Auto-synthesizing does not work for properties declared in a protocol, so we
// have to explicitly synthesize these properties that are declared in the
// Tile protocol.
@synthesize row = _row;
@synthesize column = _column;

#pragma mark - Initialization and deallocation

// -----------------------------------------------------------------------------
/// @brief Initializes a NodeNumbersTileView object with frame rectangle
/// @a rect.
///
/// @note This is the designated initializer of NodeNumbersTileView.
// -----------------------------------------------------------------------------
- (id) initWithFrame:(CGRect)rect
{
  // Call designated initializer of superclass (UIView)
  self = [super initWithFrame:rect];
  if (! self)
    return nil;

  self.row = -1;
  self.column = -1;
  self.notificationRespondersAreSetup = false;
  self.drawLayerWasDelayed = false;
  [self setupLayer];

  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this NodeNumbersTileView object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [self removeNotificationResponders];

  [self.dummyLayerDelegate.layer removeFromSuperlayer];

  [super dealloc];
}

#pragma mark - View setup

// -----------------------------------------------------------------------------
/// @brief Private helper for the initializer.
// -----------------------------------------------------------------------------
- (void) setupLayer
{
  NodeTreeViewMetrics* metrics = [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics;
  self.dummyLayerDelegate = [[[DummyLayerDelegate alloc] initWithTile:self
                                                              metrics:metrics] autorelease];
  [self.layer addSublayer:self.dummyLayerDelegate.layer];
}

#pragma mark - Setup/remove notification responders

// -----------------------------------------------------------------------------
/// @brief Private helper for the initializer.
// -----------------------------------------------------------------------------
- (void) setupNotificationResponders
{
  if (self.notificationRespondersAreSetup)
    return;
  self.notificationRespondersAreSetup = true;

  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(longRunningActionEnds:) name:longRunningActionEnds object:nil];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for dealloc.
// -----------------------------------------------------------------------------
- (void) removeNotificationResponders
{
  if (! self.notificationRespondersAreSetup)
    return;
  self.notificationRespondersAreSetup = false;

  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Handle delayed drawing

// -----------------------------------------------------------------------------
/// @brief Internal helper that correctly handles delayed drawing of the view
/// layer. NodeNumbersTileView methods that need a view update should
/// invoke this helper instead of drawLayer().
///
/// If no long-running actions are in progress, this helper invokes
/// drawLayer(), thus triggering the update in UIKit.
///
/// If any long-running actions are in progress, this helper sets
/// @e drawLayerWasDelayed to true.
// -----------------------------------------------------------------------------
- (void) delayedDrawLayer
{
  if ([LongRunningActionCounter sharedCounter].counter > 0)
    self.drawLayerWasDelayed = true;
  else
    [self drawLayer];
}

// -----------------------------------------------------------------------------
/// @brief Notifies the view layer that it needs to update now if it is dirty.
/// This marks one update cycle.
// -----------------------------------------------------------------------------
- (void) drawLayer
{
  // No game -> no board -> no drawing. This situation exists right after the
  // application has launched and the initial game is created only after a
  // small delay.
  if (! [GoGame sharedGame])
    return;

  if ([NSThread currentThread] != [NSThread mainThread])
  {
    [self performSelectorOnMainThread:@selector(drawLayer) withObject:nil waitUntilDone:YES];
    return;
  }

  self.drawLayerWasDelayed = false;
  [self.dummyLayerDelegate drawLayer];
}

#pragma mark - Tile protocol overrides

// -----------------------------------------------------------------------------
/// @brief Tile protocol method
// -----------------------------------------------------------------------------
- (void) invalidateContent
{
  [self.dummyLayerDelegate notify:NTVLDEventInvalidateContent eventInfo:nil];
  [self delayedDrawLayer];
}

#pragma mark - Notification responders

// -----------------------------------------------------------------------------
/// @brief Responds to the #longRunningActionEnds notification.
// -----------------------------------------------------------------------------
- (void) longRunningActionEnds:(NSNotification*)notification
{
  if (self.drawLayerWasDelayed)
    [self drawLayer];
}

#pragma mark - KVO responder

// -----------------------------------------------------------------------------
/// @brief Responds to KVO notifications.
// -----------------------------------------------------------------------------
- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
}

#pragma mark - UIView overrides

// -----------------------------------------------------------------------------
/// @brief UIView method.
///
/// If this NodeNumbersTileView is added to a superview (i.e.
/// @a newSuperview is not nil), this NodeNumbersTileView registers to
/// receive notifications so that it can participate in drawing. It also
/// invalidates the content of its layers so that it redraws in the next
/// drawing cycle. This make sures that the tile view is drawing its content
/// the first time after it is newly allocated, or after it is reused.
///
/// If this NodeNumbersTileView is removed from its superview (i.e.
/// @a newSuperview is nil), this NodeNumbersTileView unregisters from all
/// notifications so that it no longer takes part in the drawing process.
// -----------------------------------------------------------------------------
- (void) willMoveToSuperview:(UIView*)newSuperview
{
  if (newSuperview)
  {
    [self setupNotificationResponders];
    [self invalidateContent];
  }
  else
  {
    [self removeNotificationResponders];
  }
}

// -----------------------------------------------------------------------------
/// @brief UIView method.
///
/// This implementation is not strictly required because
/// NodeNumbersTileView is currently not used in conjunction with Auto
/// Layout.
// -----------------------------------------------------------------------------
- (CGSize) intrinsicContentSize
{
  return [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics.tileSize;
}

@end
