// -----------------------------------------------------------------------------
// Copyright 2015-2022 Patrick Näf (herzbube@herzbube.ch)
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
#import "BoardPositionCollectionViewCell.h"
#import "../../go/GoGame.h"
#import "../../go/GoMove.h"
#import "../../go/GoNode.h"
#import "../../go/GoNodeAnnotation.h"
#import "../../go/GoNodeModel.h"
#import "../../go/GoPlayer.h"
#import "../../go/GoPoint.h"
#import "../../go/GoUtilities.h"
#import "../../go/GoVertex.h"
#import "../../ui/AutoLayoutUtility.h"
#import "../../ui/UiElementMetrics.h"
#import "../../ui/UiUtilities.h"
#import "../../utility/MarkupUtilities.h"
#import "../../utility/NSStringAdditions.h"
#import "../../utility/UIColorAdditions.h"
#import "../../utility/UIImageAdditions.h"


enum BoardPositionCollectionViewCellType
{
  BoardPositionCollectionViewCellTypePositionZero,
  BoardPositionCollectionViewCellTypePositionNonZero
};


// This variable must be accessed via [BoardPositionCollectionViewCell boardPositionCollectionViewCellSizePositionZero]
static CGSize boardPositionCollectionViewCellSizePositionZero = { 0.0f, 0.0f };
// This variable must be accessed via [BoardPositionCollectionViewCell boardPositionCollectionViewCellSizePositionNonZero]
static CGSize boardPositionCollectionViewCellSizePositionNonZero = { 0.0f, 0.0f };
static int horizontalSpacingSuperview = 0;
static int horizontalSpacingSiblings = 0;
static int verticalSpacingSuperview = 0;
static int verticalSpacingSiblings = 0;
static int stoneImageWidthAndHeight = 0;
static int iconImageWidthAndHeight = 0;
static int verticalSpacingIconImages = 0;
static UIImage* blackStoneImage = nil;
static UIImage* whiteStoneImage = nil;
static UIImage* infoIconImage = nil;
static UIImage* hotspotIconImage = nil;
static UIImage* markupIconImage = nil;
static UIColor* currentBoardPositionCellBackgroundColor = nil;
static UIColor* alternateCellBackgroundColor1 = nil;
static UIColor* alternateCellBackgroundColor2 = nil;
static UIColor* alternateCellBackgroundColor1DarkMode = nil;
static UIColor* alternateCellBackgroundColor2DarkMode = nil;
static UIColor* capturedStonesLabelBackgroundColor = nil;
static UIFont* largeFont = nil;
static UIFont* smallFont = nil;


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for
/// BoardPositionCollectionViewCell.
// -----------------------------------------------------------------------------
@interface BoardPositionCollectionViewCell()
@property(nonatomic, assign) bool offscreenMode;
@property(nonatomic, assign) UIImageView* stoneImageView;
@property(nonatomic, assign) UILabel* intersectionLabel;
@property(nonatomic, assign) UILabel* boardPositionLabel;
@property(nonatomic, assign) UILabel* capturedStonesLabel;
@property(nonatomic, assign) UIImageView* infoIconImageView;
@property(nonatomic, assign) UIImageView* hotspotIconImageView;
@property(nonatomic, assign) UIImageView* markupIconImageView;
@property(nonatomic, retain) NSArray* dynamicAutoLayoutConstraints;
@end


@implementation BoardPositionCollectionViewCell

#pragma mark - Initialization and deallocation

// -----------------------------------------------------------------------------
/// @brief Initializes a BoardPositionCollectionViewCell object with frame
/// @a rect.
///
/// @note This is the designated initializer of BoardPositionCollectionViewCell.
// -----------------------------------------------------------------------------
- (id) initWithFrame:(CGRect)rect
{
  // Call designated initializer of superclass (UICollectionViewCell)
  self = [super initWithFrame:rect];
  if (! self)
    return nil;

  self.offscreenMode = false;
  _boardPosition = -1;             // don't use self, we don't want to trigger the setter
  self.dynamicAutoLayoutConstraints = nil;

  [self setupViewHierarchy];
  [self setupAutoLayoutConstraints];
  [self configureView];

  // No content to setup, we first need a board position
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Initializes a BoardPositionCollectionViewCell object that is never
/// rendered on screen.
///
/// @note This initializer is privately used for the one-time pre-calculation
/// of the BoardPositionCollectionViewCell size. The calculated size depends on
/// @a cellType.
// -----------------------------------------------------------------------------
- (id) initOffscreenViewWithCellType:(enum BoardPositionCollectionViewCellType)cellType
{
  // The frame for the off-screen view can be pretty much any size, the view
  // will be resized by setupStaticViewMetrics to UILayoutFittingCompressedSize
  // anyway. There is one restriction though: The frame must be large enough to
  // accomodate all spacings set up by setupAutoLayoutConstraints(). If the
  // frame is not large enough (e.g. CGRectZero) Auto Layout will print a
  // warning to the debug console, but continue by breaking one of the
  // constraints.
  CGRect frame = CGRectMake(0, 0, 100, 100);
  // Call designated initializer of superclass (UICollectionViewCell)
  self = [super initWithFrame:frame];
  if (! self)
    return nil;

  self.offscreenMode = true;
  if (cellType == BoardPositionCollectionViewCellTypePositionZero)
    _boardPosition = 0;
  else
    _boardPosition = 1;
  self.dynamicAutoLayoutConstraints = nil;

  [self setupViewHierarchy];
  // Setup content first because dynamic Auto Layout constraint calculation
  // examines the content
  [self setupDummyContent];
  [self setupAutoLayoutConstraints];
  [self configureView];

  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this BoardPositionCollectionViewCell
/// object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  self.stoneImageView = nil;
  self.intersectionLabel = nil;
  self.boardPositionLabel = nil;
  self.capturedStonesLabel = nil;
  self.infoIconImageView = nil;
  self.hotspotIconImageView = nil;
  self.markupIconImageView = nil;
  self.dynamicAutoLayoutConstraints = nil;
  [super dealloc];
}

#pragma mark - View setup

// -----------------------------------------------------------------------------
/// @brief Private helper for the initializers.
// -----------------------------------------------------------------------------
- (void) setupViewHierarchy
{
  self.stoneImageView = [[[UIImageView alloc] initWithImage:nil] autorelease];
  self.intersectionLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
  self.boardPositionLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
  self.capturedStonesLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
  self.infoIconImageView = [[[UIImageView alloc] initWithImage:nil] autorelease];
  self.hotspotIconImageView = [[[UIImageView alloc] initWithImage:nil] autorelease];
  self.markupIconImageView = [[[UIImageView alloc] initWithImage:nil] autorelease];
  [self addSubview:self.stoneImageView];
  [self addSubview:self.intersectionLabel];
  [self addSubview:self.boardPositionLabel];
  [self addSubview:self.capturedStonesLabel];
  [self addSubview:self.infoIconImageView];
  [self addSubview:self.hotspotIconImageView];
  [self addSubview:self.markupIconImageView];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for the initializers.
// -----------------------------------------------------------------------------
- (void) setupAutoLayoutConstraints
{
  self.stoneImageView.translatesAutoresizingMaskIntoConstraints = NO;
  self.intersectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.boardPositionLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.capturedStonesLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.infoIconImageView.translatesAutoresizingMaskIntoConstraints = NO;
  self.hotspotIconImageView.translatesAutoresizingMaskIntoConstraints = NO;
  self.markupIconImageView.translatesAutoresizingMaskIntoConstraints = NO;

  NSMutableDictionary* viewsDictionary = [NSMutableDictionary dictionary];
  NSMutableArray* visualFormats = [NSMutableArray array];

  viewsDictionary[@"intersectionLabel"] = self.intersectionLabel;
  viewsDictionary[@"boardPositionLabel"] = self.boardPositionLabel;
  viewsDictionary[@"capturedStonesLabel"] = self.capturedStonesLabel;
  viewsDictionary[@"hotspotIconImageView"] = self.hotspotIconImageView;
  // Spacing 0 is OK. In setupDummyContents we reserve space for a
  // 3-digit number of captured stones, which is unlikely to occur.
  // Numbers with 1 or 2 digits are much more likely, so the space
  // reserved for a 2nd and/or 3rd digit acts as spacing (the label
  // text is right-aligned). In the unlikely event that there *IS*
  // a 3-digit number, spacing 0 is still tolerable.
  [visualFormats addObject:@"H:[intersectionLabel]-0-[capturedStonesLabel]"];
  // Spacing 0 is OK. boardPositionLabel gets more than enough width
  // so that even with the longest text in it there is always a bit
  // of leftover space at the right to act as spacing.
  [visualFormats addObject:@"H:[boardPositionLabel]-0-[hotspotIconImageView]"];
  [visualFormats addObject:[NSString stringWithFormat:@"V:|-%d-[intersectionLabel]-%d-[boardPositionLabel]-%d-|", verticalSpacingSuperview, verticalSpacingSiblings, verticalSpacingSuperview]];
  [AutoLayoutUtility installVisualFormats:visualFormats withViews:viewsDictionary inView:self.intersectionLabel.superview];

  [AutoLayoutUtility centerSubview:self.stoneImageView
                       inSuperview:self
                            onAxis:UILayoutConstraintAxisVertical];
  [AutoLayoutUtility alignFirstView:self.capturedStonesLabel
                     withSecondView:self.intersectionLabel
                        onAttribute:NSLayoutAttributeCenterY
                   constraintHolder:self];

  UIView* anchorView = self;
  NSLayoutXAxisAnchor* leftAnchor;
  NSLayoutXAxisAnchor* rightAnchor;
  if (@available(iOS 11.0, *))
  {
    UILayoutGuide* layoutGuide = anchorView.safeAreaLayoutGuide;
    leftAnchor = layoutGuide.leftAnchor;
    rightAnchor = layoutGuide.rightAnchor;
  }
  else
  {
    leftAnchor = anchorView.leftAnchor;
    rightAnchor = anchorView.rightAnchor;
  }
  [self.stoneImageView.leftAnchor constraintEqualToAnchor:leftAnchor constant:horizontalSpacingSuperview].active = YES;
  [self.infoIconImageView.rightAnchor constraintEqualToAnchor:rightAnchor constant:-horizontalSpacingSuperview].active = YES;
  [self.markupIconImageView.rightAnchor constraintEqualToAnchor:rightAnchor constant:-horizontalSpacingSuperview].active = YES;

  [self updateDynamicAutoLayoutConstraints];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for the initializers.
// -----------------------------------------------------------------------------
- (void) configureView
{
  self.backgroundView.accessibilityIdentifier = unselectedBackgroundViewBoardPositionAccessibilityIdentifier;

  self.selectedBackgroundView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
  self.selectedBackgroundView.backgroundColor = currentBoardPositionCellBackgroundColor;
  self.selectedBackgroundView.accessibilityIdentifier = selectedBackgroundViewBoardPositionAccessibilityIdentifier;

  self.intersectionLabel.font = largeFont;
  self.boardPositionLabel.font = smallFont;
  self.capturedStonesLabel.font = smallFont;

  self.capturedStonesLabel.textAlignment = NSTextAlignmentRight;
  self.capturedStonesLabel.textColor = capturedStonesLabelBackgroundColor;

  self.intersectionLabel.accessibilityIdentifier = intersectionLabelBoardPositionAccessibilityIdentifier;
  self.boardPositionLabel.accessibilityIdentifier = boardPositionLabelBoardPositionAccessibilityIdentifier;
  self.capturedStonesLabel.accessibilityIdentifier = capturedStonesLabelBoardPositionAccessibilityIdentifier;
}

// -----------------------------------------------------------------------------
/// @brief Private helper for the designated initializer and the
/// @e boardPosition property setter.
// -----------------------------------------------------------------------------
- (void) setupRealContent
{
  if (-1 == self.boardPosition)
    return;

  GoGame* game = [GoGame sharedGame];
  GoNode* node = [self nodeWithDataOrNil];

  if (0 == self.boardPosition)
  {
    self.stoneImageView.image = nil;
    self.intersectionLabel.text = @"Start of the game";
    NSString* komiString = [NSString stringWithKomi:game.komi numericZeroValue:true];
    self.boardPositionLabel.text = [NSString stringWithFormat:@"Handicap: %1lu, Komi: %@", (unsigned long)game.handicapPoints.count, komiString];
    self.capturedStonesLabel.text = nil;
    self.infoIconImageView.image = nil;
    self.hotspotIconImageView.image = nil;
    self.markupIconImageView.image = nil;
  }
  else
  {
    if ([self showsMoveData:node])
    {
      GoMove* move = node.goMove;
      self.stoneImageView.image = [self stoneImageForMove:move];
      self.intersectionLabel.text = [self intersectionLabelTextForMove:move];
      self.boardPositionLabel.text = [NSString stringWithFormat:@"Move %d", node.goMove.moveNumber];
      self.capturedStonesLabel.text = [self capturedStonesLabelTextForMove:move];
    }
    else
    {
      self.stoneImageView.image = nil;
      self.intersectionLabel.text = @"No move";
      self.boardPositionLabel.text = nil;
      self.capturedStonesLabel.text = nil;
    }

    if ([self showsInfoIcon:node])
      self.infoIconImageView.image = infoIconImage;
    else
      self.infoIconImageView.image = nil;

    if ([self showsHotspotIcon:node])
      self.hotspotIconImageView.image = hotspotIconImage;
    else
      self.hotspotIconImageView.image = nil;

    if ([self showsMarkupIcon:node])
      self.markupIconImageView.image = markupIconImage;
    else
      self.markupIconImageView.image = nil;
  }

  // Let UI tests distinguish which image is set. Experimentally determined that
  // we can't set the individual UIImage's accessibilityIdentifier property
  // (even though it exists), XCTest never finds any UIImages configured like
  // that. Presumably this is because XCTest only exposes views, and UIImage is
  // not a view - but UIImageView is.
  if (self.stoneImageView.image == nil)
    self.stoneImageView.accessibilityIdentifier = noStoneImageViewBoardPositionAccessibilityIdentifier;
  else if (self.stoneImageView.image == blackStoneImage)
    self.stoneImageView.accessibilityIdentifier = blackStoneImageViewBoardPositionAccessibilityIdentifier;
  else
    self.stoneImageView.accessibilityIdentifier = whiteStoneImageViewBoardPositionAccessibilityIdentifier;

  [self updateColors:node];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for the offscreen initializer.
// -----------------------------------------------------------------------------
- (void) setupDummyContent
{
  // Implementation note: Assign the longest strings that can possibly appear.

  if (0 == self.boardPosition)
  {
    self.stoneImageView.image = nil;
    self.intersectionLabel.text = @"Start of the game";
    self.boardPositionLabel.text = @"Handicap: 9, Komi: 7½";
    // Dynamic Auto Layout constraint calculation requires that we set nil here
    self.capturedStonesLabel.text = nil;
    self.infoIconImageView.image = nil;
    self.hotspotIconImageView.image = nil;
    self.markupIconImageView.image = nil;
  }
  else
  {
    self.stoneImageView.image = blackStoneImage;
    // The longest string is actually "No move", but this is used only when the
    // stone image is not displayed, which compensates for the longer string
    self.intersectionLabel.text = @"Q19";
    self.boardPositionLabel.text = @"Move 999";
    self.capturedStonesLabel.text = @"999";
    self.infoIconImageView.image = infoIconImage;
    self.hotspotIconImageView.image = hotspotIconImage;
    self.markupIconImageView.image = markupIconImage;
  }
}

// -----------------------------------------------------------------------------
/// @brief Private helper for setupRealContent().
// -----------------------------------------------------------------------------
- (NSString*) intersectionLabelTextForMove:(GoMove*)move
{
  if (GoMoveTypePlay == move.type)
    return move.point.vertex.string;
  else
    return @"Pass";
}

// -----------------------------------------------------------------------------
/// @brief Private helper for setupRealContent().
// -----------------------------------------------------------------------------
- (UIImage*) stoneImageForMove:(GoMove*)move
{
  if (move.player.black)
    return blackStoneImage;
  else
    return whiteStoneImage;
}

// -----------------------------------------------------------------------------
/// @brief Private helper for setupRealContent().
///
/// @attention Dynamic Auto Layout constraint calculation requires that we
/// return nil if @a move did not capture any stones.
// -----------------------------------------------------------------------------
- (NSString*) capturedStonesLabelTextForMove:(GoMove*)move
{
  if (GoMoveTypePass == move.type)
    return nil;
  NSUInteger numberOfCapturedStones = move.capturedStones.count;
  if (0 == numberOfCapturedStones)
    return nil;
  return [NSString stringWithFormat:@"%lu", (unsigned long)numberOfCapturedStones];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for setupRealContent().
// -----------------------------------------------------------------------------
- (bool) showsMoveData:(GoNode*)node
{
  if (self.offscreenMode)
    return true;

  if (node.goMove)
    return true;
  else
    return false;
}

// -----------------------------------------------------------------------------
/// @brief Private helper for setupRealContent().
// -----------------------------------------------------------------------------
- (bool) showsInfoIcon:(GoNode*)node
{
  if (self.offscreenMode)
    return true;
  else
    return [GoUtilities showInfoIndicatorForNode:node];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for setupRealContent().
// -----------------------------------------------------------------------------
- (bool) showsHotspotIcon:(GoNode*)node
{
  if (self.offscreenMode)
    return true;
  else
    return [GoUtilities showHotspotIndicatorForNode:node];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for setupRealContent().
// -----------------------------------------------------------------------------
- (bool) showsMarkupIcon:(GoNode*)node
{
  if (self.offscreenMode)
    return true;
  else
    return [MarkupUtilities shouldDisplayMarkupIndicatorForNode:node];
}

#pragma mark - UIView overrides

// -----------------------------------------------------------------------------
/// @brief UIView method.
// -----------------------------------------------------------------------------
- (void) traitCollectionDidChange:(UITraitCollection*)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];

  if (@available(iOS 12.0, *))
  {
    if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle)
    {
      // traitCollectionDidChange sometimes is invoked when a cell is reused
      // before the boardPosition property value was updated. If that is the
      // case then we don't get a GoNode object => there's no point in updating
      // the colors, so we skip it and let setupRealContent do it later when the
      // boardPosition property is updated.
      GoNode* node = [self nodeWithDataOrNil];
      if (node)
        [self updateColors:node];
    }
  }
}

#pragma mark - Property setters

// -----------------------------------------------------------------------------
// Property is documented in the header file.
// -----------------------------------------------------------------------------
- (void) setBoardPosition:(int)newValue
{
  bool newBoardPositionRequiresAutoLayoutConstraintUpdate;
  if (_boardPosition == -1)
  {
    newBoardPositionRequiresAutoLayoutConstraintUpdate = true;
  }
  else
  {
    bool oldPositionIsGreaterThanZero = (_boardPosition > 0);
    bool newPositionIsGreaterThanZero = (newValue > 0);
    newBoardPositionRequiresAutoLayoutConstraintUpdate = (oldPositionIsGreaterThanZero != newPositionIsGreaterThanZero);
  }

  _boardPosition = newValue;

  bool oldPositionShowsMove = (self.stoneImageView.image != nil);
  bool oldPositionHasCapturedStones = (self.capturedStonesLabel.text != nil);
  bool oldPositionShowsInfoIcon = (self.infoIconImageView.image != nil);
  bool oldPositionShowsHotspotIcon = (self.hotspotIconImageView.image != nil);
  bool oldPositionShowsMarkupIcon = (self.markupIconImageView.image != nil);
  // Setup content first because dynamic Auto Layout constraint calculation
  // examines the content
  [self setupRealContent];
  bool newPositionShowsMove = (self.stoneImageView.image != nil);
  bool newPositionHasCapturedStones = (self.capturedStonesLabel.text != nil);
  bool newPositionShowsInfoIcon = (self.infoIconImageView.image != nil);
  bool newPositionShowsHotspotIcon = (self.hotspotIconImageView.image != nil);
  bool newPositionShowsMarkupIcon = (self.markupIconImageView.image != nil);

  // Optimization: Change Auto Layout constraints only if absolutely necessary
  if (newBoardPositionRequiresAutoLayoutConstraintUpdate ||
      oldPositionShowsMove != newPositionShowsMove ||
      oldPositionHasCapturedStones != newPositionHasCapturedStones ||
      oldPositionShowsInfoIcon != newPositionShowsInfoIcon ||
      oldPositionShowsHotspotIcon != newPositionShowsHotspotIcon ||
      oldPositionShowsMarkupIcon != newPositionShowsMarkupIcon)
  {
    [self updateDynamicAutoLayoutConstraints];
  }
}

#pragma mark - Dynamic Auto Layout constraints

// -----------------------------------------------------------------------------
/// @brief Updates dynamic layout constraints according to the current content
/// of this cell.
// -----------------------------------------------------------------------------
- (void) updateDynamicAutoLayoutConstraints
{
  if (self.dynamicAutoLayoutConstraints)
    [self removeConstraints:self.dynamicAutoLayoutConstraints];

  NSDictionary* viewsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                   self.stoneImageView, @"stoneImageView",
                                   self.intersectionLabel, @"intersectionLabel",
                                   self.boardPositionLabel, @"boardPositionLabel",
                                   self.capturedStonesLabel, @"capturedStonesLabel",
                                   self.infoIconImageView, @"infoIconImageView",
                                   self.hotspotIconImageView, @"hotspotIconImageView",
                                   self.markupIconImageView, @"markupIconImageView",
                                   nil];
  int stoneImageWidth = 0;
  int horizontalSpacingStoneImageView = 0;
  int infoIconImageViewWidth = 0;
  int hotspotIconImageViewWidth = 0;
  int markupIconImageViewWidth = 0;
  int horizontalSpacingInfoIconImageView = 0;
  int horizontalSpacingBottomIcons = 0;
  if (self.boardPosition > 0)
  {
    if (self.stoneImageView.image)
    {
      stoneImageWidth = stoneImageWidthAndHeight;
      horizontalSpacingStoneImageView = horizontalSpacingSiblings;
    }
    else
    {
      stoneImageWidth = 0;
      horizontalSpacingStoneImageView = 0;
    }

    if (self.infoIconImageView.image)
    {
      infoIconImageViewWidth = iconImageWidthAndHeight;
      // If there are no captured stones the spacing can remain 0 - the info
      // icon image is then directly adjacent to intersectionLabel, and in that
      // label there is always sufficient space left to act as spacing.
      if (self.capturedStonesLabel.text)
        horizontalSpacingInfoIconImageView = horizontalSpacingSiblings;
    }
    else
    {
      infoIconImageViewWidth = 0;
    }

    if (self.hotspotIconImageView.image)
      hotspotIconImageViewWidth = iconImageWidthAndHeight;
    else
      hotspotIconImageViewWidth = 0;

    if (self.markupIconImageView.image)
      markupIconImageViewWidth = iconImageWidthAndHeight;
    else
      markupIconImageViewWidth = 0;

    if (self.hotspotIconImageView.image && self.markupIconImageView.image)
      horizontalSpacingBottomIcons = horizontalSpacingSiblings / 2.0f;  // a bit of spacing is required, but as minimal as possible
    else
      horizontalSpacingBottomIcons = 0;
  }
  else
  {
    stoneImageWidth = 0;
    horizontalSpacingStoneImageView = 0;
    infoIconImageViewWidth = 0;
    hotspotIconImageViewWidth = 0;
    markupIconImageViewWidth = 0;
    horizontalSpacingBottomIcons = 0;
  }

  NSMutableArray* visualFormats = [NSMutableArray array];
  [visualFormats addObject:[NSString stringWithFormat:@"H:[stoneImageView(==%d)]", stoneImageWidth]];
  [visualFormats addObject:[NSString stringWithFormat:@"H:[stoneImageView]-%d-[intersectionLabel]", horizontalSpacingStoneImageView]];
  [visualFormats addObject:[NSString stringWithFormat:@"H:[stoneImageView]-%d-[boardPositionLabel]", horizontalSpacingStoneImageView]];
  if (! self.boardPositionLabel.text)
    [visualFormats addObject:@"V:[boardPositionLabel(==0)]"];
  if (nil == self.capturedStonesLabel.text)
    [visualFormats addObject:@"H:[capturedStonesLabel(==0)]"];
  [visualFormats addObject:[NSString stringWithFormat:@"H:[capturedStonesLabel]-%d-[infoIconImageView(==%d)]", horizontalSpacingInfoIconImageView, infoIconImageViewWidth]];
  [visualFormats addObject:[NSString stringWithFormat:@"H:[hotspotIconImageView(==%d)]", hotspotIconImageViewWidth]];
  [visualFormats addObject:[NSString stringWithFormat:@"H:[markupIconImageView(==%d)]", markupIconImageViewWidth]];
  [visualFormats addObject:[NSString stringWithFormat:@"H:[hotspotIconImageView]-%d-[markupIconImageView]", horizontalSpacingBottomIcons]];
  NSArray* visualFormatsAutoLayoutConstraints = [AutoLayoutUtility installVisualFormats:visualFormats
                                                                              withViews:viewsDictionary
                                                                                 inView:self];

  // Because boardPositionLabel is sometimes not displayed the vertical
  // positioning of the icon images needs to be dynamic. If boardPositionLabel
  // is not shown, the hotspot icon and markup icon images are aligned instead
  // on the center of intersectionLabel. In addition if both the info icon
  // image in the top row and one or both of the icon images in the bottom row
  // are shown, the two rows need to have a bit of spacing in between.
  CGFloat infoIconAlignModifier = 0.0f;
  UIView* bottomIconsAlignView = nil;
  CGFloat bottomIconsAlignModifier = 0.0f;
  if (self.boardPositionLabel.text)
  {
    bottomIconsAlignView = self.boardPositionLabel;
  }
  // The else branch relies on intersectionLabel being always shown
  else
  {
    bottomIconsAlignView = self.intersectionLabel;

    if (self.infoIconImageView.image && (self.hotspotIconImageView.image || self.markupIconImageView.image))
    {
      infoIconAlignModifier = -((infoIconImageViewWidth + verticalSpacingIconImages) / 2.0f);
      if (self.hotspotIconImageView.image)
        bottomIconsAlignModifier = (hotspotIconImageViewWidth + verticalSpacingIconImages) / 2.0f;
      else
        bottomIconsAlignModifier = (markupIconImageViewWidth + verticalSpacingIconImages) / 2.0f;
    }
  }

  NSLayoutConstraint* infoIconAutoLayoutConstraints = nil;
  NSLayoutConstraint* hotspotIconAutoLayoutConstraints = nil;
  NSLayoutConstraint* markupIconAutoLayoutConstraints = nil;
  if (self.infoIconImageView.image)
  {
    infoIconAutoLayoutConstraints = [AutoLayoutUtility alignFirstView:self.infoIconImageView
                                                       withSecondView:self.intersectionLabel
                                                          onAttribute:NSLayoutAttributeCenterY
                                                         withConstant:infoIconAlignModifier
                                                     constraintHolder:self];
  }
  if (self.hotspotIconImageView.image)
  {
    hotspotIconAutoLayoutConstraints = [AutoLayoutUtility alignFirstView:self.hotspotIconImageView
                                                          withSecondView:bottomIconsAlignView
                                                             onAttribute:NSLayoutAttributeCenterY
                                                            withConstant:bottomIconsAlignModifier
                                                        constraintHolder:self];
  }
  if (self.markupIconImageView.image)
  {
    markupIconAutoLayoutConstraints = [AutoLayoutUtility alignFirstView:self.markupIconImageView
                                                         withSecondView:bottomIconsAlignView
                                                            onAttribute:NSLayoutAttributeCenterY
                                                           withConstant:bottomIconsAlignModifier
                                                       constraintHolder:self];
  }

  if (infoIconAutoLayoutConstraints || bottomIconsAlignView)
  {
    NSMutableArray* dynamicAutoLayoutConstraints = [NSMutableArray arrayWithArray:visualFormatsAutoLayoutConstraints];
    if (infoIconAutoLayoutConstraints)
      [dynamicAutoLayoutConstraints addObject:infoIconAutoLayoutConstraints];
    if (hotspotIconAutoLayoutConstraints)
      [dynamicAutoLayoutConstraints addObject:hotspotIconAutoLayoutConstraints];
    if (markupIconAutoLayoutConstraints)
      [dynamicAutoLayoutConstraints addObject:markupIconAutoLayoutConstraints];
    self.dynamicAutoLayoutConstraints = dynamicAutoLayoutConstraints;
  }
  else
  {
    self.dynamicAutoLayoutConstraints = visualFormatsAutoLayoutConstraints;
  }
}

#pragma mark - User interface style handling (light/dark mode)

// -----------------------------------------------------------------------------
/// @brief Updates all kinds of colors to match the current
/// UIUserInterfaceStyle (light/dark mode).
// -----------------------------------------------------------------------------
- (void) updateColors:(GoNode*)node
{
  bool isLightUserInterfaceStyle = [UiUtilities isLightUserInterfaceStyle:self.traitCollection];

  if (0 == (self.boardPosition % 2))
    self.backgroundColor = isLightUserInterfaceStyle ? alternateCellBackgroundColor1 : alternateCellBackgroundColor1DarkMode;
  else
    self.backgroundColor = isLightUserInterfaceStyle ? alternateCellBackgroundColor2 : alternateCellBackgroundColor2DarkMode;

  UIColor* iconTintColor = isLightUserInterfaceStyle ? [UIColor blackColor] : [UIColor whiteColor];;

  if (self.infoIconImageView.image)
    self.infoIconImageView.tintColor = iconTintColor;

  if (self.markupIconImageView.image)
    self.markupIconImageView.tintColor = iconTintColor;

  if (self.hotspotIconImageView.image)
  {
    GoNodeAnnotation* nodeAnnotation = node ? node.goNodeAnnotation : nil;
    enum GoBoardPositionHotspotDesignation goBoardPositionHotspotDesignation = nodeAnnotation ? nodeAnnotation.goBoardPositionHotspotDesignation : GoBoardPositionHotspotDesignationNone;
    if (goBoardPositionHotspotDesignation == GoBoardPositionHotspotDesignationYesEmphasized)
      self.hotspotIconImageView.tintColor = [UIColor hotspotColor:goBoardPositionHotspotDesignation];
    else
      self.hotspotIconImageView.tintColor = iconTintColor;
  }
}

#pragma mark - Helpers

// -----------------------------------------------------------------------------
/// @brief Returns the GoNode object whose data is displayed by the cell.
/// Returns @e nil if the cell refers to a node that does not exist. This can
/// occur if this method is invoked for a reused cell before the cell's
/// @e boardPosition property has been updated.
// -----------------------------------------------------------------------------
- (GoNode*) nodeWithDataOrNil
{
  GoNodeModel* nodeModel = [GoGame sharedGame].nodeModel;

  int nodeIndex = self.boardPosition;
  if (nodeIndex >= nodeModel.numberOfNodes)
    return nil;

  GoNode* node = [nodeModel nodeAtIndex:nodeIndex];
  return node;
}

#pragma mark - One-time view size calculation

// -----------------------------------------------------------------------------
/// @brief Returns the pre-calculated size of a BoardPositionCollectionViewCell
/// instance that represents board position 0.
///
/// When this method is invoked the first time, it performs the necessary size
/// calculations.
// -----------------------------------------------------------------------------
+ (CGSize) boardPositionCollectionViewCellSizePositionZero
{
  if (CGSizeEqualToSize(boardPositionCollectionViewCellSizePositionZero, CGSizeZero))
    [BoardPositionCollectionViewCell setupStaticViewMetrics];
  return boardPositionCollectionViewCellSizePositionZero;
}

// -----------------------------------------------------------------------------
/// @brief Returns the pre-calculated size of a BoardPositionCollectionViewCell
/// instance that represents a non-zero board position.
///
/// When this method is invoked the first time, it performs the necessary size
/// calculations.
// -----------------------------------------------------------------------------
+ (CGSize) boardPositionCollectionViewCellSizePositionNonZero
{
  if (CGSizeEqualToSize(boardPositionCollectionViewCellSizePositionNonZero, CGSizeZero))
    [BoardPositionCollectionViewCell setupStaticViewMetrics];
  return boardPositionCollectionViewCellSizePositionNonZero;
}

// -----------------------------------------------------------------------------
/// @brief Private helper for boardPositionCollectionViewCellSize().
// -----------------------------------------------------------------------------
+ (void) setupStaticViewMetrics
{
  horizontalSpacingSuperview = [UiElementMetrics horizontalSpacingSiblings];
  horizontalSpacingSiblings = [UiElementMetrics horizontalSpacingSiblings];
  verticalSpacingSuperview = [UiElementMetrics horizontalSpacingSiblings] / 2;
  verticalSpacingSiblings = 0;
  verticalSpacingIconImages = [UiElementMetrics verticalSpacingSiblings] / 2;

  stoneImageWidthAndHeight = floor([UiElementMetrics tableViewCellContentViewHeight] * 0.7);
  CGSize stoneImageSize = CGSizeMake(stoneImageWidthAndHeight, stoneImageWidthAndHeight);
  blackStoneImage = [[[UIImage imageNamed:stoneBlackImageResource] imageByResizingToSize:stoneImageSize] retain];
  whiteStoneImage = [[[UIImage imageNamed:stoneWhiteImageResource] imageByResizingToSize:stoneImageSize] retain];

  iconImageWidthAndHeight = floor([UiElementMetrics tableViewCellContentViewHeight] * 0.3);
  CGSize iconImageSize = CGSizeMake(iconImageWidthAndHeight, iconImageWidthAndHeight);
  infoIconImage = [[[UIImage imageNamed:uiAreaAboutIconResource] templateImageByResizingToSize:iconImageSize] retain];
  markupIconImage = [[[UIImage imageNamed:markupIconResource] templateImageByResizingToSize:iconImageSize] retain];
  hotspotIconImage = [[[UIImage imageNamed:hotspotIconResource] templateImageByResizingToSize:iconImageSize] retain];

  currentBoardPositionCellBackgroundColor = [[UIColor darkTangerineColor] retain];
  alternateCellBackgroundColor1 = [[UIColor lightBlueColor] retain];
  alternateCellBackgroundColor2 = [[UIColor whiteColor] retain];
  if (@available(iOS 13.0, *))
  {
    alternateCellBackgroundColor1DarkMode = [UIColor systemGrayColor];
    alternateCellBackgroundColor2DarkMode = [UIColor systemGray2Color];
  }
  else
  {
    alternateCellBackgroundColor1DarkMode = alternateCellBackgroundColor1;
    alternateCellBackgroundColor2DarkMode = alternateCellBackgroundColor2;
  }
  capturedStonesLabelBackgroundColor = [[UIColor redColor] retain];

  largeFont = [[UIFont systemFontOfSize:17] retain];
  smallFont = [[UIFont systemFontOfSize:11] retain];

  enum BoardPositionCollectionViewCellType cellType = BoardPositionCollectionViewCellTypePositionZero;
  BoardPositionCollectionViewCell* offscreenView = [[[BoardPositionCollectionViewCell alloc] initOffscreenViewWithCellType:cellType] autorelease];
  [offscreenView layoutIfNeeded];
  boardPositionCollectionViewCellSizePositionZero = [offscreenView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];

  cellType = BoardPositionCollectionViewCellTypePositionNonZero;
  offscreenView = [[[BoardPositionCollectionViewCell alloc] initOffscreenViewWithCellType:cellType] autorelease];
  [offscreenView layoutIfNeeded];
  boardPositionCollectionViewCellSizePositionNonZero = [offscreenView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];

  // If values with fractions are used there is bound to be a rounding error
  // at some stage, either when the cell sizes are passed to the collection view
  // or when the cell sizes are used for Auto Layout constraints.
  boardPositionCollectionViewCellSizePositionZero = CGSizeMake(ceilf(boardPositionCollectionViewCellSizePositionZero.width),
                                                               ceilf(boardPositionCollectionViewCellSizePositionZero.height));
  boardPositionCollectionViewCellSizePositionNonZero = CGSizeMake(ceilf(boardPositionCollectionViewCellSizePositionNonZero.width),
                                                                  ceilf(boardPositionCollectionViewCellSizePositionNonZero.height));
}

@end
