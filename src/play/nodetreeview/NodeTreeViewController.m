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
#import "NodeTreeViewController.h"
#import "NodeNumbersTileView.h"
#import "NodeTreeTileView.h"
#import "NodeTreeView.h"
#import "../model/NodeTreeViewMetrics.h"
#import "../../main/ApplicationDelegate.h"
#import "../../ui/AutoLayoutUtility.h"
//#import "../../utility/UIColorAdditions.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for NodeTreeViewController.
// -----------------------------------------------------------------------------
@interface NodeTreeViewController()
/// @brief Prevents unregistering by dealloc if registering hasn't happened
/// yet. Registering may not happen if the controller's view is never loaded.
@property(nonatomic, assign) bool notificationRespondersAreSetup;
@property(nonatomic, assign) bool viewDidLayoutSubviewsInProgress;
@property(nonatomic, retain) NodeTreeView* nodeTreeView;
@property(nonatomic, retain) TiledScrollView* nodeNumbersView;
@property(nonatomic, retain) NSArray* nodeNumbersViewConstraints;
@end


@implementation NodeTreeViewController

#pragma mark - Initialization and deallocation

// -----------------------------------------------------------------------------
/// @brief Initializes a NodeTreeViewController object.
///
/// @note This is the designated initializer of NodeTreeViewController.
// -----------------------------------------------------------------------------
- (id) init
{
  // Call designated initializer of superclass (UIViewController)
  self = [super initWithNibName:nil bundle:nil];
  if (! self)
    return nil;

  self.notificationRespondersAreSetup = false;
  self.viewDidLayoutSubviewsInProgress = false;
  self.nodeTreeView = nil;
  self.nodeNumbersView = nil;
  self.nodeNumbersViewConstraints = nil;
  [self setupChildControllers];

  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this NodeTreeViewController object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [self removeNotificationResponders];
  self.nodeNumbersViewConstraints = nil;
  self.nodeTreeView = nil;
  self.nodeNumbersView = nil;

  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Private helper invoked during initialization.
// -----------------------------------------------------------------------------
- (void) setupChildControllers
{
}

#pragma mark - loadView and helpers

// -----------------------------------------------------------------------------
/// @brief UIViewController method.
// -----------------------------------------------------------------------------
- (void) loadView
{
  [super loadView];

  [self createSubviews];
  [self setupViewHierarchy];
  [self setupAutoLayoutConstraints];
  [self configureViews];
  [self configureControllers];
  [self setupNotificationResponders];

  [self createOrDeallocNodeNumbersView];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for loadView.
// -----------------------------------------------------------------------------
- (void) createSubviews
{
  self.nodeTreeView = [[[NodeTreeView alloc] initWithFrame:CGRectZero] autorelease];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for loadView.
// -----------------------------------------------------------------------------
- (void) setupViewHierarchy
{
  [self.view addSubview:self.nodeTreeView];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for loadView.
// -----------------------------------------------------------------------------
- (void) setupAutoLayoutConstraints
{
  self.nodeTreeView.translatesAutoresizingMaskIntoConstraints = NO;
  [AutoLayoutUtility fillSuperview:self.view withSubview:self.nodeTreeView];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for loadView.
// -----------------------------------------------------------------------------
- (void) configureViews
{
  NodeTreeViewMetrics* metrics = [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics;

  self.nodeTreeView.backgroundColor = [UIColor clearColor];
  self.nodeTreeView.delegate = self;
  // After an interface orientation change the board may already be zoomed
  // (e.g. iPhone 6+), so we have to take the current absolute zoom scale into
  // account
  self.nodeTreeView.minimumZoomScale = metrics.minimumAbsoluteZoomScale / metrics.absoluteZoomScale;
  self.nodeTreeView.maximumZoomScale = metrics.maximumAbsoluteZoomScale / metrics.absoluteZoomScale;
  self.nodeTreeView.dataSource = self;
  self.nodeTreeView.tileSize = metrics.tileSize;
}

// -----------------------------------------------------------------------------
/// @brief Private helper for loadView.
// -----------------------------------------------------------------------------
- (void) configureControllers
{
}

#pragma mark - viewDidLayoutSubviews

// -----------------------------------------------------------------------------
/// @brief UIViewController method.
///
/// This override exists to resize the scroll view content after a change to
/// the interface orientation.
// -----------------------------------------------------------------------------
- (void) viewDidLayoutSubviews
{
  self.viewDidLayoutSubviewsInProgress = true;
  // First prepare the new tree geometry. This triggers a re-draw of all tiles.
  // TODO xxx really?
  [self updateBaseSizeInNodeTreeViewMetrics];
  // Now prepare all scroll views with the new content size. The content size
  // is taken from the values in NodeTreeViewMetrics.
  [self updateContentSizeInMainScrollView];
  [self updateContentSizeInNodeNumbersScrollView];
  self.viewDidLayoutSubviewsInProgress = false;
}

#pragma mark - Setup/remove notification responders

// -----------------------------------------------------------------------------
/// @brief Private helper.
// -----------------------------------------------------------------------------
- (void) setupNotificationResponders
{
  if (self.notificationRespondersAreSetup)
    return;
  self.notificationRespondersAreSetup = true;

  NodeTreeViewMetrics* metrics = [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics;
  [metrics addObserver:self forKeyPath:@"canvasSize" options:0 context:NULL];
}

// -----------------------------------------------------------------------------
/// @brief Private helper.
// -----------------------------------------------------------------------------
- (void) removeNotificationResponders
{
  if (! self.notificationRespondersAreSetup)
    return;
  self.notificationRespondersAreSetup = false;

  NodeTreeViewMetrics* metrics = [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics;
  [metrics removeObserver:self forKeyPath:@"canvasSize"];
}

#pragma mark TiledScrollViewDataSource overrides

// -----------------------------------------------------------------------------
/// @brief TiledScrollViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (UIView*) tiledScrollView:(TiledScrollView*)tiledScrollView tileViewForRow:(int)row column:(int)column
{
  UIView<Tile>* tileView = (UIView<Tile>*)[tiledScrollView dequeueReusableTileView];
  if (! tileView)
  {
    // The scroll view will set the tile view frame, so we don't have to worry
    // about it
    if (tiledScrollView == self.nodeTreeView)
      tileView = [[[NodeTreeTileView alloc] initWithFrame:CGRectZero] autorelease];
    else if (tiledScrollView == self.nodeNumbersView)
      tileView = [[[NodeNumbersTileView alloc] initWithFrame:CGRectZero] autorelease];
  }
  tileView.row = row;
  tileView.column = column;
  return tileView;
}

// -----------------------------------------------------------------------------
/// @brief TiledScrollViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (CGFloat) tiledScrollViewZoomScaleAtZoomStart:(TiledScrollView*)tiledScrollView
{
  // When a zoom operation completes, this controllers always resets the scroll
  // view's zoom scale to 1.0. This means that a zoom will always start at zoom
  // scale 1.0.
  return 1.0;
}

#pragma mark UIScrollViewDelegate overrides

// -----------------------------------------------------------------------------
/// @brief UIScrollViewDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) scrollViewDidScroll:(UIScrollView*)scrollView
{
  // The node number scroll view is not visible during zooming, so we don't
  // need to synchronize
  if (! scrollView.zooming)
    [self updateContentOffsetInNodeNumbersScrollView];
}

// -----------------------------------------------------------------------------
/// @brief UIScrollViewDelegate protocol method.
// -----------------------------------------------------------------------------
- (UIView*) viewForZoomingInScrollView:(UIScrollView*)scrollView
{
  return self.nodeTreeView.tileContainerView;
}

// -----------------------------------------------------------------------------
/// @brief UIScrollViewDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) scrollViewWillBeginZooming:(UIScrollView*)scrollView withView:(UIView*)view
{
  // Temporarily hide node numbers while a zoom operation is in progress.
  // Synchronizing the node numbers scroll view's zoom scale, content offset
  // and frame size while the zoom operation is in progress is a lot of effort,
  // and even though the view is zoomed formally correct the end result looks
  // like shit (because the numbers are not part of the NodeTreeView they zoom
  // differently). So instead of trying hard and failing we just dispense with
  // the effort.
  [self updateNodeNumbersVisibleState];
}

// -----------------------------------------------------------------------------
/// @brief UIScrollViewDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) scrollViewDidEndZooming:(UIScrollView*)scrollView withView:(UIView*)view atScale:(CGFloat)scale
{
  NodeTreeViewMetrics* metrics = [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics;
  CGFloat oldAbsoluteZoomScale = metrics.absoluteZoomScale;
  [metrics updateWithRelativeZoomScale:scale];

  // updateWithRelativeZoomScale:() may have adjusted the absolute zoom scale
  // in a way that makes the original value of the scale parameter obsolete.
  // We therefore calculate a new, correct value.
  CGFloat newAbsoluteZoomScale = metrics.absoluteZoomScale;
  scale = newAbsoluteZoomScale / oldAbsoluteZoomScale;

  // Remember content offset so that we can re-apply it after we reset the zoom
  // scale to 1.0. Note: The content size will be recalculated.
  CGPoint contentOffset = scrollView.contentOffset;

  // Big change here: This resets the scroll view's contentSize and
  // contentOffset, and also the tile container view's frame, bounds and
  // transform properties
  scrollView.zoomScale = 1.0f;
  // Adjust the minimum and maximum zoom scale so that the user cannot zoom
  // in/out more than originally intended
  scrollView.minimumZoomScale = scrollView.minimumZoomScale / scale;
  scrollView.maximumZoomScale = scrollView.maximumZoomScale / scale;

  // Restore properties that were changed when the zoom scale was reset to 1.0
  [self updateContentSizeInMainScrollView];
  [self updateContentSizeInNodeNumbersScrollView];
  // TODO The content offset that we remembered above may no longer be
  // accurate because NodeTreeViewMetrics may have made some adjustments to the
  // zoom scale. To fix this we either need to record the contentOffset in
  // NodeTreeViewMetrics (so that the metrics can perform the adjustments on the
  // offset as well), or we need to adjust the content offset ourselves by
  // somehow calculating the difference between the original scale (scale
  // parameter) and the adjusted scale. In that case NodeTreeViewMetrics must
  // provide us with the adjusted scale (zoomScale is the absolute scale).
  scrollView.contentOffset = contentOffset;

  [self updateContentOffsetInNodeNumbersScrollView];

  // Show node numbers that were temporarily hidden when the zoom
  // operation started
  [self updateNodeNumbersVisibleState];
}

#pragma mark - Manage node numbers view

// -----------------------------------------------------------------------------
/// @brief Creates or deallocates the node numbers view depending on xxx
// -----------------------------------------------------------------------------
- (void) createOrDeallocNodeNumbersView
{
  if ([self nodeNumbersViewShouldExist])
  {
    if ([self nodeNumbersViewExists])
      return;
    Class nodeNumbersTileViewClass = [NodeNumbersTileView class];
    self.nodeNumbersView = [[[TiledScrollView alloc] initWithFrame:CGRectZero tileViewClass:nodeNumbersTileViewClass] autorelease];
    [self.view addSubview:self.nodeNumbersView];
    [self addNodeNumbersViewConstraints];
    [self configureNodeNumbersView:self.nodeNumbersView];
    [self updateContentSizeInNodeNumbersScrollView];
    [self updateContentOffsetInNodeNumbersScrollView];
  }
  else
  {
    if (! [self nodeNumbersViewExists])
      return;
    [self removeNodeNumbersViewConstraints];
    [self.nodeNumbersView removeFromSuperview];
    self.nodeNumbersView = nil;
  }
}

// -----------------------------------------------------------------------------
/// @brief Returns true if the node numbers view should exist.
// -----------------------------------------------------------------------------
- (bool) nodeNumbersViewShouldExist
{
  return true;
}

// -----------------------------------------------------------------------------
/// @brief Returns true if the node numbers view currently exists.
// -----------------------------------------------------------------------------
- (bool) nodeNumbersViewExists
{
  return (self.nodeNumbersView != nil);
}

// -----------------------------------------------------------------------------
/// @brief Creates and adds auto layout constraints for layouting the node
/// numbers view.
// -----------------------------------------------------------------------------
- (void) addNodeNumbersViewConstraints
{
  self.nodeNumbersView.translatesAutoresizingMaskIntoConstraints = NO;
  self.nodeNumbersViewConstraints = [self createNodeNumbersViewConstraints];
  [self.view addConstraints:self.nodeNumbersViewConstraints];
}

// -----------------------------------------------------------------------------
/// @brief Removes and deallocates auto layout constraints for layouting the
/// node numbers view.
// -----------------------------------------------------------------------------
- (void) removeNodeNumbersViewConstraints
{
  if (! self.nodeNumbersViewConstraints)
    return;
  [self.view removeConstraints:self.nodeNumbersViewConstraints];
  self.nodeNumbersViewConstraints = nil;
}

// -----------------------------------------------------------------------------
/// @brief Creates and returns an array of auto layout constraints for
/// layouting coordinate labels views.
// -----------------------------------------------------------------------------
- (NSArray*) createNodeNumbersViewConstraints
{
  NodeTreeViewMetrics* metrics = [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics;
  return [NSArray arrayWithObjects:
          [NSLayoutConstraint constraintWithItem:self.nodeNumbersView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1 constant:0],
          [NSLayoutConstraint constraintWithItem:self.nodeNumbersView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1 constant:0],
          [NSLayoutConstraint constraintWithItem:self.nodeNumbersView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:0],
          [NSLayoutConstraint constraintWithItem:self.nodeNumbersView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:metrics.tileSize.height],
          nil];
}

// -----------------------------------------------------------------------------
/// @brief Configures the specified coordinate labels view after it was created.
// -----------------------------------------------------------------------------
- (void) configureNodeNumbersView:(TiledScrollView*)nodeNumbersView
{
  NodeTreeViewMetrics* metrics = [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics;
  nodeNumbersView.backgroundColor = [UIColor clearColor];
  nodeNumbersView.dataSource = self;
  nodeNumbersView.tileSize = metrics.tileSize;
  nodeNumbersView.userInteractionEnabled = NO;
}

// -----------------------------------------------------------------------------
/// @brief Hides the nodenumbers view while a zoom operation is in progress.
/// Shows the view while no zooming is in progress. Does nothing if the view
/// currently does not exist.
// -----------------------------------------------------------------------------
- (void) updateNodeNumbersVisibleState
{
  if (! [self nodeNumbersViewExists])
    return;

  BOOL hidden = self.nodeTreeView.zooming;
  self.nodeNumbersView.hidden = hidden;
}

#pragma mark - Private helpers

// -----------------------------------------------------------------------------
/// @brief Private helper.
///
/// Updates the NodeTreeViewMetrics object's content size, triggering a redraw
/// in all tiles.
// -----------------------------------------------------------------------------
- (void) updateBaseSizeInNodeTreeViewMetrics
{
  NodeTreeViewMetrics* metrics = [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics;
  [metrics updateWithBaseSize:self.view.bounds.size];
}

// -----------------------------------------------------------------------------
/// @brief Private helper.
///
/// Updates the content size of all scroll views to match the current values in
/// NodeTreeViewMetrics.
// -----------------------------------------------------------------------------
- (void) updateContentSizeInMainScrollView
{
  NodeTreeViewMetrics* metrics = [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics;
  CGSize contentSize = metrics.canvasSize;
  CGRect tileContainerViewFrame = CGRectZero;
  tileContainerViewFrame.size = contentSize;

  self.nodeTreeView.contentSize = contentSize;
  self.nodeTreeView.tileContainerView.frame = tileContainerViewFrame;
}

// -----------------------------------------------------------------------------
/// @brief Private helper.
///
/// Updates the node numbers scroll view's content size to match current
/// values from NodeTreeViewMetrics.
// -----------------------------------------------------------------------------
- (void) updateContentSizeInNodeNumbersScrollView
{
  NodeTreeViewMetrics* metrics = [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics;
  CGSize contentSize = metrics.canvasSize;
  CGSize tileSize = metrics.tileSize;
  CGRect tileContainerViewFrame = CGRectZero;

  self.nodeNumbersView.contentSize = CGSizeMake(contentSize.width, tileSize.height);
  tileContainerViewFrame.size = self.nodeNumbersView.contentSize;
  self.nodeNumbersView.tileContainerView.frame = tileContainerViewFrame;
}

// -----------------------------------------------------------------------------
/// @brief Private helper.
///
/// Synchronizes the node numbers scroll view's content offset with the
/// master scroll view.
// -----------------------------------------------------------------------------
- (void) updateContentOffsetInNodeNumbersScrollView
{
  CGPoint nodeNumbersViewContentOffset = self.nodeNumbersView.contentOffset;
  nodeNumbersViewContentOffset.x = self.nodeTreeView.contentOffset.x;
  self.nodeNumbersView.contentOffset = nodeNumbersViewContentOffset;
}

#pragma mark - KVO notification

// -----------------------------------------------------------------------------
/// @brief Responds to KVO notifications.
// -----------------------------------------------------------------------------
- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if (object == [ApplicationDelegate sharedDelegate].nodeTreeViewMetrics)
  {
    if ([keyPath isEqualToString:@"canvasSize"])
    {
      // The node number view depends on the node number strip width,
      // which may change significantly when the node tree geometry changes
      // (rect property).
      if ([NSThread currentThread] != [NSThread mainThread])
      {
        // Make sure that our handler executes on the main thread because it
        // creates or deallocates views and generally calls thread-unsafe UIKit
        // functions. A KVO notification can come in on a secondary thread when
        // a game is loaded from the archive, or when a game is restored during
        // app launch.
        [self performSelectorOnMainThread:@selector(createOrDeallocNodeNumbersView) withObject:nil waitUntilDone:NO];
      }
      else
      {
        if (self.viewDidLayoutSubviewsInProgress)
        {
          // UIKit sometimes crashes if we add the node numbers view while a
          // layouting cycle is in progress. The crash happens if 1) the app
          // starts up and initially displays some other than the Play UI area,
          // then 2) the user switches to the Play UI area. At this moment
          // viewDidLayoutSubviews is executed, it invokes
          // updateBaseSizeInNodeTreeViewMetrics, which in turn triggers this
          // KVO observer. If we now add the node numbers view, the app crashes.
          // The exact reason for the crash is unknown, but probable causes are
          // either adding subviews, or adding constraints, in the middle of a
          // layouting cycle. The workaround is to add a bit of asynchrony.
          [self performSelector:@selector(createOrDeallocNodeNumbersView) withObject:nil afterDelay:0];
        }
        else
        {
          [self createOrDeallocNodeNumbersView];
        }
      }
    }
  }
}

@end
