// -----------------------------------------------------------------------------
// Copyright 2011-2022 Patrick Näf (herzbube@herzbube.ch)
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
#import "MoreGameActionsController.h"
#import "../gameaction/GameActionManager.h"
#import "../../archive/ArchiveUtility.h"
#import "../../archive/ArchiveViewModel.h"
#import "../../command/backup/BackupGameToSgfCommand.h"
#import "../../command/backup/CleanBackupSgfCommand.h"
#import "../../command/game/SaveGameCommand.h"
#import "../../command/game/NewGameCommand.h"
#import "../../command/game/ResumePlayCommand.h"
#import "../../command/playerinfluence/GenerateTerritoryStatisticsCommand.h"
#import "../../command/ChangeUIAreaPlayModeCommand.h"
#import "../../go/GoBoardPosition.h"
#import "../../go/GoGame.h"
#import "../../go/GoGameDocument.h"
#import "../../go/GoGameRules.h"
#import "../../go/GoMove.h"
#import "../../go/GoScore.h"
#import "../../go/GoUtilities.h"
#import "../../main/ApplicationDelegate.h"
#import "../../play/model/BoardViewModel.h"
#import "../../play/model/ScoringModel.h"
#import "../../shared/ApplicationStateManager.h"
#import "../../ui/UiSettingsModel.h"
#import "../../ui/UIViewControllerAdditions.h"
#import "../../utility/NSStringAdditions.h"


@implementation MoreGameActionsController

#pragma mark - Initialization and deallocation

// -----------------------------------------------------------------------------
/// @brief Initializes a MoreGameActionsController object.
///
/// @a aController refers to a view controller based on which modal view
/// controllers can be displayed.
///
/// @a delegate is the delegate object that will be informed when this
/// controller has finished its task.
///
/// @note This is the designated initializer of MoreGameActionsController.
// -----------------------------------------------------------------------------
- (id) initWithModalMaster:(UIViewController*)aController delegate:(id<MoreGameActionsControllerDelegate>)aDelegate
{
  // Call designated initializer of superclass (NSObject)
  self = [super init];
  if (! self)
    return nil;
  self.delegate = aDelegate;
  self.modalMaster = aController;
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this MoreGameActionsController
/// object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  self.delegate = nil;
  self.modalMaster = nil;
  [super dealloc];
}

#pragma mark - Displaying and canceling the alert message

// -----------------------------------------------------------------------------
/// @brief Displays the alert message as described in the class documentation.
// -----------------------------------------------------------------------------
- (void) showAlertMessageFromBarButtonItem:(UIBarButtonItem*)barButtonItem
{
  UIAlertController* alertController = [self showAlertMessage];

  // As documented in the UIPopoverPresentationController class reference,
  // we should wait with accessing the presentation controller until after we
  // initiate the presentation, otherwise the controller may not have been
  // created yet. Furthermore, a presentation controller is only created on
  // the iPad, but not on the iPhone, so we check for the controller's
  // existence before using it.
  if (alertController.popoverPresentationController)
    alertController.popoverPresentationController.barButtonItem = barButtonItem;
}

// -----------------------------------------------------------------------------
/// @brief Displays the alert message as described in the class documentation.
// -----------------------------------------------------------------------------
- (void) showAlertMessageFromRect:(CGRect)rect inView:(UIView*)view
{
  UIAlertController* alertController = [self showAlertMessage];

  // See comment in showAlertMessageFromBarButtonItem:()
  if (alertController.popoverPresentationController)
  {
    alertController.popoverPresentationController.sourceView = view;
    alertController.popoverPresentationController.sourceRect = rect;
  }
}

// -----------------------------------------------------------------------------
/// @brief Initiates displaying the alert message as described in the class
/// documentation. The caller has to check if the alert is to be presented with
/// a UIPopoverPresentationController, and if yes must configure that controller
/// with the correct source.
// -----------------------------------------------------------------------------
- (UIAlertController*) showAlertMessage
{
  UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"Game actions"
                                                                           message:nil
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];

  GoGame* game = [GoGame sharedGame];

  ApplicationDelegate* applicationDelegate = [ApplicationDelegate sharedDelegate];
  enum UIAreaPlayMode uiAreaPlayMode = applicationDelegate.uiSettingsModel.uiAreaPlayMode;

  // Add buttons in the order that they appear in the MoreGameActionsButton enum
  for (int iterButtonIndex = 0; iterButtonIndex < MoreGameActionsButtonMax; ++iterButtonIndex)
  {
    NSString* title = nil;
    void (^alertActionBlock) (UIAlertAction*) = nil;
    UIAlertActionStyle alertActionStyle = UIAlertActionStyleDefault;

    switch (iterButtonIndex)
    {
      case MoreGameActionsButtonSetupFirstMove:
      {
        if (uiAreaPlayMode != UIAreaPlayModeBoardSetup)
          continue;
        title = @"Set up a side to play first";
        alertActionBlock = ^(UIAlertAction* action) { [self setupFirstMove]; };
        break;

      }
      case MoreGameActionsButtonBoardSetup:
      {
        if (game.boardPosition.currentBoardPosition > 0)
          continue;
        if (uiAreaPlayMode != UIAreaPlayModePlay && uiAreaPlayMode != UIAreaPlayModeScoring && uiAreaPlayMode != UIAreaPlayModeEditMarkup)
          continue;
        title = @"Set up board";
        alertActionBlock = ^(UIAlertAction* action) { [self setupBoard]; };
        break;
      }
      case MoreGameActionsButtonScore:
      {
        // If game has ended there is a dedicated button for enabling scoring
        // mode, so no need to show this option in our menu
        if (GoGameStateGameHasEnded == game.state)
          continue;
        if (uiAreaPlayMode != UIAreaPlayModePlay && uiAreaPlayMode != UIAreaPlayModeBoardSetup && uiAreaPlayMode != UIAreaPlayModeEditMarkup)
          continue;
        title = @"Score";
        alertActionBlock = ^(UIAlertAction* action) { [self score]; };
        break;
      }
      case MoreGameActionsButtonEditMarkup:
      {
        if (uiAreaPlayMode != UIAreaPlayModePlay && uiAreaPlayMode != UIAreaPlayModeScoring && uiAreaPlayMode != UIAreaPlayModeBoardSetup)
          continue;
        title = @"Edit markup";
        alertActionBlock = ^(UIAlertAction* action) { [self editMarkup]; };
        break;
      }
      case MoreGameActionsButtonMarkAsSeki:
      case MoreGameActionsButtonMarkAsDead:
      {
        if (uiAreaPlayMode != UIAreaPlayModeScoring)
          continue;
        switch (game.reasonForGameHasEnded)
        {
          case GoGameHasEndedReasonFourPasses:
            continue;
          default:
            break;
        }
        ScoringModel* model = applicationDelegate.scoringModel;
        switch (model.scoreMarkMode)
        {
          case GoScoreMarkModeDead:
          {
            if (iterButtonIndex == MoreGameActionsButtonMarkAsDead)
              continue;
            title = @"Start marking as seki";
            break;
          }
          case GoScoreMarkModeSeki:
          {
            if (iterButtonIndex == MoreGameActionsButtonMarkAsSeki)
              continue;
            title = @"Start marking as dead";
            break;
          }
          default:
          {
            assert(0);
            return nil;
          }
        }
        alertActionBlock = ^(UIAlertAction* action) { [self toggleScoringMarkMode]; };
        break;
      }
      case MoreGameActionsButtonUpdatePlayerInfluence:
      {
        BoardViewModel* model = applicationDelegate.boardViewModel;
        if (! model.displayPlayerInfluence)
          continue;
        if (uiAreaPlayMode != UIAreaPlayModePlay)
          continue;
        title = @"Update player influence";
        alertActionBlock = ^(UIAlertAction* action) { [self updatePlayerInfluence]; };
        break;
      }
      case MoreGameActionsButtonSetBlackToMove:
      case MoreGameActionsButtonSetWhiteToMove:
      {
        if (uiAreaPlayMode != UIAreaPlayModePlay)
          continue;
        // Currently we only support switching colors in order to settle a
        // life & death dispute, immediately after play was resumed, and only if
        // the rules allow non-alternating play.
        if (![GoUtilities isGameInResumedPlayState:game])
          continue;
        if (game.rules.disputeResolutionRule != GoDisputeResolutionRuleNonAlternatingPlay)
          continue;
        // In a computer vs. computer game there is no point in allowing to
        // switch colors
        if (GoGameTypeComputerVsComputer == game.type)
          continue;
        enum GoColor alternatingNextMoveColor = [GoUtilities alternatingColorForColor:game.nextMoveColor];
        if (alternatingNextMoveColor == GoColorBlack && iterButtonIndex == MoreGameActionsButtonSetWhiteToMove)
          continue;
        else if (alternatingNextMoveColor == GoColorWhite && iterButtonIndex == MoreGameActionsButtonSetBlackToMove)
          continue;
        NSString* alternatingNextMoveColorName = [[NSString stringWithGoColor:alternatingNextMoveColor] lowercaseString];
        title = [NSString stringWithFormat:@"Set %@ to move", alternatingNextMoveColorName];
        alertActionBlock = ^(UIAlertAction* action) { [self switchNextMoveColor]; };
        break;
      }
      case MoreGameActionsButtonResumePlay:
      {
        if (uiAreaPlayMode != UIAreaPlayModePlay)
          continue;
        bool shouldAllowResumePlay = [GoUtilities shouldAllowResumePlay:game];
        if (!shouldAllowResumePlay)
          continue;
        title = @"Resume play";
        alertActionBlock = ^(UIAlertAction* action) { [self resumePlay]; };
        break;
      }
      case MoreGameActionsButtonResign:
      {
        if (uiAreaPlayMode != UIAreaPlayModePlay)
          continue;
        if (GoGameTypeComputerVsComputer == game.type)
          continue;
        if (GoGameStateGameHasEnded == game.state)
          continue;
        if (game.nextMovePlayerIsComputerPlayer)
          continue;
        if ([GoUtilities nodeWithNextMoveExists:game.boardPosition.currentNode])
          continue;
        title = @"Resign";
        alertActionBlock = ^(UIAlertAction* action) { [self resign]; };
        break;
      }
      case MoreGameActionsButtonUndoResign:
      case MoreGameActionsButtonUndoTimeout:
      case MoreGameActionsButtonUndoForfeit:
      {
        if (uiAreaPlayMode != UIAreaPlayModePlay && uiAreaPlayMode != UIAreaPlayModeScoring)
          continue;
        if (GoGameStateGameHasEnded != game.state)
          continue;
        if ([GoUtilities nodeWithNextMoveExists:game.boardPosition.currentNode])
          continue;
        switch (game.reasonForGameHasEnded)
        {
          case GoGameHasEndedReasonBlackWinsByResignation:
          case GoGameHasEndedReasonWhiteWinsByResignation:
            if (iterButtonIndex != MoreGameActionsButtonUndoResign)
              continue;
            title = @"Undo resign";
            break;
          case GoGameHasEndedReasonBlackWinsOnTime:
          case GoGameHasEndedReasonWhiteWinsOnTime:
            if (iterButtonIndex != MoreGameActionsButtonUndoTimeout)
              continue;
            title = @"Undo timeout";
            break;
          case GoGameHasEndedReasonBlackWinsByForfeit:
          case GoGameHasEndedReasonWhiteWinsByForfeit:
            if (iterButtonIndex != MoreGameActionsButtonUndoForfeit)
              continue;
            title = @"Undo forfeit";
            break;
          default:
            continue;
        }
        alertActionBlock = ^(UIAlertAction* action) { [self revertGameStateFromEndedToInProgress]; };
        break;
      }
      case MoreGameActionsButtonSaveGame:
      {
        title = @"Save game";
        alertActionBlock = ^(UIAlertAction* action) { [self saveGame]; };
        break;
      }
      case MoreGameActionsButtonNewGame:
      {
        title = @"New game";
        alertActionBlock = ^(UIAlertAction* action) { [self newGame]; };
        break;
      }
      case MoreGameActionsButtonNewGameRematch:
      {
        title = @"New game - Rematch";
        alertActionBlock = ^(UIAlertAction* action) { [self newGameRematch]; };
        break;
      }

      // For UITypePhone in Landscape interface orientation the maximum number
      // of actions that are visible at the same time is rather limited (6 if
      // you include the "Cancel" action). Although UIAlertViewController lets
      // the user scroll when there are more actions, it's not immediately
      // obvious that there are hidden actions that one can reach by scrolling.
      // It is therefore better to avoid having too many actions in the first
      // place. With the addition of MoreGameActionsButtonNewGameRematch the
      // limit of 6 actions has already been exceeded. If you're reading this
      // because you want to add yet another action, instead consider a
      // different solution, or try to somehow redesign the app so that one or
      // more of the existing actions can be removed.

      case MoreGameActionsButtonCancel:
      {
        title = @"Cancel";
        // On the iPad the "Cancel" button is not displayed, but if the user
        // taps outside of the popover the cancel action's handler is called
        alertActionBlock = ^(UIAlertAction* action) { [self.delegate moreGameActionsControllerDidFinish:self]; };
        alertActionStyle = UIAlertActionStyleCancel;
        break;
      }
      default:
      {
        DDLogError(@"%@: Showing alert message with unexpected button type %d", self, iterButtonIndex);
        assert(0);
        break;
      }
    }

    UIAlertAction* action = [UIAlertAction actionWithTitle:title
                                                     style:alertActionStyle
                                                   handler:alertActionBlock];
    [alertController addAction:action];
  }

  [self.modalMaster presentViewController:alertController animated:YES completion:nil];

  return alertController;
}

// -----------------------------------------------------------------------------
/// @brief Cancels the alert message if it is currently displayed.
// -----------------------------------------------------------------------------
- (void) cancelAlertMessage
{
  // Dismiss the UIAlertController
  [self.modalMaster dismissViewControllerAnimated:NO completion:nil];
  // Dismissing the UIAlertController did not trigger the cancel button,
  // so we must inform the delegate ourselves
  [self.delegate moreGameActionsControllerDidFinish:self];

  // Don't do anything else, informing the delegate that we are done (see above)
  // caused this MoreGameActionsController to be deallocated
}

#pragma mark - Handling tap gestures

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Set up a side to play first" button.
/// Displays a controller that lets the user select a side. The actual setup
/// operation takes place in doSetupFirstMove:().
// -----------------------------------------------------------------------------
- (void) setupFirstMove
{
  NSString* screenTitle = @"Side to play first";
  NSString* footerTitle = @"Select \"Game rules\" if you want the normal game rules to apply. For instance, in a handicap game the normal game rules specify that white moves first. Select one of the other options if you want to override the normal game rules.";

  NSMutableArray* itemList = [NSMutableArray arrayWithCapacity:3];
  itemList[GoColorNone] = @"Game rules";
  itemList[GoColorBlack] = @"Black";
  itemList[GoColorWhite] = @"White";

  int indexOfDefaultItem = [GoGame sharedGame].setupFirstMoveColor;

  ItemPickerController* itemPickerController = [ItemPickerController controllerWithItemList:itemList
                                                                                screenTitle:screenTitle
                                                                         indexOfDefaultItem:indexOfDefaultItem
                                                                                   delegate:self];
  itemPickerController.footerTitle = footerTitle;
  [self.modalMaster presentNavigationControllerWithRootViewController:itemPickerController];
}

// -----------------------------------------------------------------------------
/// @brief Performs the actual "setup first move" operation.
// -----------------------------------------------------------------------------
- (void) doSetupFirstMove:(enum GoColor)firstMoveColor
{
  [[GameActionManager sharedGameActionManager] handleSetupFirstMove:firstMoveColor];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Set up board" button. Switches the
/// UI area "Play" to board setup mode.
// -----------------------------------------------------------------------------
- (void) setupBoard
{
  [[[[ChangeUIAreaPlayModeCommand alloc] initWithUIAreaPlayMode:UIAreaPlayModeBoardSetup] autorelease] submit];
  [self.delegate moreGameActionsControllerDidFinish:self];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Score" button. Enables scoring mode.
// -----------------------------------------------------------------------------
- (void) score
{
  [[GameActionManager sharedGameActionManager] scoringStart:self];
  [self.delegate moreGameActionsControllerDidFinish:self];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Edit markup" button. Switches the
/// UI area "Play" to markup editing mode.
// -----------------------------------------------------------------------------
- (void) editMarkup
{
  [[[[ChangeUIAreaPlayModeCommand alloc] initWithUIAreaPlayMode:UIAreaPlayModeEditMarkup] autorelease] submit];
  [self.delegate moreGameActionsControllerDidFinish:self];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Start marking as [...]" button.
/// Toggles the mark mode during scoring.
// -----------------------------------------------------------------------------
- (void) toggleScoringMarkMode
{
  ScoringModel* model = [ApplicationDelegate sharedDelegate].scoringModel;
  switch (model.scoreMarkMode)
  {
    case GoScoreMarkModeDead:
    {
      model.scoreMarkMode = GoScoreMarkModeSeki;
      break;
    }
    case GoScoreMarkModeSeki:
    {
      model.scoreMarkMode = GoScoreMarkModeDead;
      break;
    }
    default:
    {
      assert(0);
      break;
    }
  }
  DDLogInfo(@"Mark mode is now %d", model.scoreMarkMode);
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Update player influence" button.
/// Triggers a long-running GTP command at the end of which the new player
/// influence values are drawn.
// -----------------------------------------------------------------------------
- (void) updatePlayerInfluence
{
  [[[[GenerateTerritoryStatisticsCommand alloc] init] autorelease] submit];
  [self.delegate moreGameActionsControllerDidFinish:self];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Set color to <foo>" button. Changes
/// the side that will play next from Black to White, or vice versa.
// -----------------------------------------------------------------------------
- (void) switchNextMoveColor
{
  @try
  {
    [[ApplicationStateManager sharedManager] beginSavePoint];
    GoGame* game = [GoGame sharedGame];
    [game switchNextMoveColor];
    DDLogInfo(@"Next move color is now %@", [NSString stringWithGoColor:game.nextMoveColor]);
  }
  @finally
  {
    [[ApplicationStateManager sharedManager] applicationStateDidChange];
    [[ApplicationStateManager sharedManager] commitSavePoint];
  }
  [self.delegate moreGameActionsControllerDidFinish:self];

}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Resign" button. Causes the human
/// player whose turn it currently is to resign the game.
// -----------------------------------------------------------------------------
- (void) resign
{
  @try
  {
    [[ApplicationStateManager sharedManager] beginSavePoint];
    GoGame* game = [GoGame sharedGame];
    DDLogInfo(@"%@ resigns", [NSString stringWithGoColor:game.nextMoveColor]);
    [game resign];
  }
  @finally
  {
    [[ApplicationStateManager sharedManager] applicationStateDidChange];
    [[ApplicationStateManager sharedManager] commitSavePoint];
  }
  [[[[BackupGameToSgfCommand alloc] init] autorelease] submit];
  [self.delegate moreGameActionsControllerDidFinish:self];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Resume play" button. Causes play to
/// be resumed, with the goal to settle life & death disputes.
// -----------------------------------------------------------------------------
- (void) resumePlay
{
  // ResumePlayCommand may show an alert message, so code execution may return
  // to us before play is actually resumed
  [[[[ResumePlayCommand alloc] init] autorelease] submit];
  [self.delegate moreGameActionsControllerDidFinish:self];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Undo resign", "Undo timeout" or
/// "Undo forfeit" button. Causes the state of the game to revert from
/// "has ended" to one of the various "in progress" states.
// -----------------------------------------------------------------------------
- (void) revertGameStateFromEndedToInProgress
{
  @try
  {
    [[ApplicationStateManager sharedManager] beginSavePoint];
    GoGame* game = [GoGame sharedGame];
    [game revertStateFromEndedToInProgress];
    DDLogInfo(@"Revert game state from 'ended' to 'in progress'");
  }
  @finally
  {
    [[ApplicationStateManager sharedManager] applicationStateDidChange];
    [[ApplicationStateManager sharedManager] commitSavePoint];
  }
  [[[[BackupGameToSgfCommand alloc] init] autorelease] submit];
  [self.delegate moreGameActionsControllerDidFinish:self];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Save game" button. Saves the current
/// game to .sgf.
// -----------------------------------------------------------------------------
- (void) saveGame
{
  ArchiveViewModel* model = [ApplicationDelegate sharedDelegate].archiveViewModel;
  NSString* defaultGameName = [model uniqueGameNameForGame:[GoGame sharedGame]];
  EditTextController* editTextController = [[EditTextController controllerWithText:defaultGameName
                                                                             style:EditTextControllerStyleTextField
                                                                          delegate:self] retain];
  editTextController.title = @"Game name";
  [self.modalMaster presentNavigationControllerWithRootViewController:editTextController];
  [editTextController release];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "New game" button. Starts a new game,
/// discarding the current game.
// -----------------------------------------------------------------------------
- (void) newGame
{
  // This controller manages the actual "New Game" view
  NewGameController* newGameController = [[NewGameController controllerWithDelegate:self loadGame:false] retain];
  [self.modalMaster presentNavigationControllerWithRootViewController:newGameController];
  [newGameController release];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "New game - Rematch" button. Starts a
/// new game, discarding the current game, but without displaying the "new game"
/// screen.
// -----------------------------------------------------------------------------
- (void) newGameRematch
{
  NewGameController* newGameController = [[[NewGameController controllerWithDelegate:self loadGame:false] retain] autorelease];
  [newGameController rematchWithAlertPresenter:self.modalMaster];
}

// -----------------------------------------------------------------------------
/// @brief NewGameControllerDelegate protocol method
// -----------------------------------------------------------------------------
- (void) newGameController:(NewGameController*)controller didStartNewGame:(bool)didStartNewGame rematch:(bool)rematch
{
  if (didStartNewGame)
  {
    [[[[CleanBackupSgfCommand alloc] init] autorelease] submit];
    [[[[NewGameCommand alloc] init] autorelease] submit];
  }

  // In the rematch use case NewGameController was not presented
  if (! rematch)
    [self.modalMaster dismissViewControllerAnimated:YES completion:nil];

  [self.delegate moreGameActionsControllerDidFinish:self];
}

// -----------------------------------------------------------------------------
/// @brief EditTextDelegate protocol method
// -----------------------------------------------------------------------------
- (bool) controller:(EditTextController*)editTextController shouldEndEditingWithText:(NSString*)text
{
  enum ArchiveGameNameValidationResult validationResult = [ArchiveUtility validateGameName:text];
  if (ArchiveGameNameValidationResultValid == validationResult)
  {
    return true;
  }
  else
  {
    [ArchiveUtility showAlertForFailedGameNameValidation:validationResult
                                          alertPresenter:editTextController];
    return false;
  }
}

// -----------------------------------------------------------------------------
/// @brief EditTextDelegate protocol method
// -----------------------------------------------------------------------------
- (void) didEndEditing:(EditTextController*)editTextController didCancel:(bool)didCancel
{
  // Dismiss EditTextController here so that self.modalMaster becomes free
  // to present the UIAlertController
  [self.modalMaster dismissViewControllerAnimated:YES completion:nil];

  bool moreGameActionsControllerDidFinish = true;
  if (! didCancel)
  {
    ArchiveViewModel* model = [ApplicationDelegate sharedDelegate].archiveViewModel;
    if ([model gameWithName:editTextController.text])
    {
      void (^yesActionBlock) (UIAlertAction*) = ^(UIAlertAction* action)
      {
        [self doSaveGame:editTextController.text gameAlreadyExists:true];
        [self.delegate moreGameActionsControllerDidFinish:self];
      };

      void (^noActionBlock) (UIAlertAction*) = ^(UIAlertAction* action)
      {
        [self.delegate moreGameActionsControllerDidFinish:self];
      };

      [self.modalMaster presentYesNoAlertWithTitle:@"Game already exists"
                                           message:@"Another game with that name already exists. Do you want to overwrite that game?"
                                                                                      yesHandler:yesActionBlock
                                                                                       noHandler:noActionBlock];

      // We are not yet finished, user must still confirm/reject the overwrite
      moreGameActionsControllerDidFinish = false;
    }
    else
    {
      [self doSaveGame:editTextController.text gameAlreadyExists:false];
    }
  }

  if (moreGameActionsControllerDidFinish)
    [self.delegate moreGameActionsControllerDidFinish:self];
}

// -----------------------------------------------------------------------------
/// @brief Performs the actual "save game" operation. The saved game is named
/// @a gameName. If a game with that name already exists, it is overwritten.
// -----------------------------------------------------------------------------
- (void) doSaveGame:(NSString*)gameName gameAlreadyExists:(bool)gameAlreadyExists
{
  [[[[SaveGameCommand alloc] initWithSaveGame:gameName gameAlreadyExists:gameAlreadyExists] autorelease] submit];
}

#pragma mark - ItemPickerDelegate overrides

// -----------------------------------------------------------------------------
/// @brief ItemPickerDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) itemPickerController:(ItemPickerController*)controller didMakeSelection:(bool)didMakeSelection
{
  // Dismiss ItemPickerController before we actually do something. Reason:
  // If a "Discard future moves" alert needs to be displayed the
  // ItemPickerController must not cover the root view controller of the app's
  // window.
  [self.modalMaster dismissViewControllerAnimated:YES completion:nil];

  if (didMakeSelection && controller.indexOfDefaultItem != controller.indexOfSelectedItem)
  {
    enum GoColor firstMoveColor = controller.indexOfSelectedItem;
    [self doSetupFirstMove:firstMoveColor];
  }

  [self.delegate moreGameActionsControllerDidFinish:self];
}

@end
