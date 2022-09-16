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
#import "DiagnosticsViewController.h"
#import "CrashReportingSettingsController.h"
#import "GtpLogViewController.h"
#import "GtpLogSettingsController.h"
#import "GtpCommandViewController.h"
#import "LoggingModel.h"
#import "SendBugReportController.h"
#import "../go/GoGame.h"
#import "../go/GoScore.h"
#import "../main/ApplicationDelegate.h"
#import "../ui/TableViewCellFactory.h"
#import "../ui/UiSettingsModel.h"


// -----------------------------------------------------------------------------
/// @brief Enumerates the sections presented in the "Diagnostics" table view.
// -----------------------------------------------------------------------------
enum DiagnosticsTableViewSection
{
  GtpSection,
  CrashReportSection,
  LoggingSection,
  BugReportSection,
  MaxSection
};

// -----------------------------------------------------------------------------
/// @brief Enumerates items in the GtpSection.
// -----------------------------------------------------------------------------
enum GtpSectionItem
{
  GtpLogItem,
  GtpCommandsItem,
  GtpSettingsItem,
  MaxGtpSectionItem
};

// -----------------------------------------------------------------------------
/// @brief Enumerates items in the CrashReportSection.
// -----------------------------------------------------------------------------
enum CrashReportSectionItem
{
  CrashReportSettingsItem,
  MaxCrashReportSectionItem
};

// -----------------------------------------------------------------------------
/// @brief Enumerates items in the LoggingSection.
// -----------------------------------------------------------------------------
enum LoggingSectionItem
{
  LoggingEnabledItem,
  MaxLoggingSectionItem
};

// -----------------------------------------------------------------------------
/// @brief Enumerates items in the BugReportSection.
// -----------------------------------------------------------------------------
enum BugReportSectionItem
{
  SendBugReportItem,
  GenerateDiagnosticsInformationFileItem,
  MaxBugReportSectionItem
};


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for
/// DiagnosticsViewController.
// -----------------------------------------------------------------------------
@interface DiagnosticsViewController()
@property(nonatomic, assign) bool notificationRespondersAreSetup;
@property(nonatomic, assign) bool bugReportSectionIsDisabled;
@property(nonatomic, assign) bool ignoreLoggingEnabledModelUpdate;
@end


@implementation DiagnosticsViewController

#pragma mark - Initialization and deallocation

// -----------------------------------------------------------------------------
/// @brief Convenience constructor. Creates a DiagnosticsViewController instance
/// of grouped style.
// -----------------------------------------------------------------------------
+ (DiagnosticsViewController*) controller
{
  DiagnosticsViewController* controller = [[DiagnosticsViewController alloc] initWithStyle:UITableViewStyleGrouped];
  if (controller)
  {
    controller.notificationRespondersAreSetup = false;
    controller.bugReportSectionIsDisabled = false;
    controller.ignoreLoggingEnabledModelUpdate = false;
    [controller autorelease];
  }
  return controller;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this DiagnosticsViewController
/// object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [self removeNotificationResponders];
  [super dealloc];
}

#pragma mark - UIViewController overrides

// -----------------------------------------------------------------------------
/// @brief UIViewController method.
// -----------------------------------------------------------------------------
- (void) viewDidLoad
{
  [super viewDidLoad];
  [self setupNotificationResponders];
  self.bugReportSectionIsDisabled = [self shouldDisableBugReportSection];
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

  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(computerPlayerThinkingChanged:) name:computerPlayerThinkingStarts object:nil];
  [center addObserver:self selector:@selector(computerPlayerThinkingChanged:) name:computerPlayerThinkingStops object:nil];
  [center addObserver:self selector:@selector(goScoreCalculationStarts:) name:goScoreCalculationStarts object:nil];
  [center addObserver:self selector:@selector(goScoreCalculationEnds:) name:goScoreCalculationEnds object:nil];
  LoggingModel* loggingModel = [ApplicationDelegate sharedDelegate].loggingModel;
  [loggingModel addObserver:self forKeyPath:@"loggingEnabled" options:0 context:NULL];
}

// -----------------------------------------------------------------------------
/// @brief Private helper.
// -----------------------------------------------------------------------------
- (void) removeNotificationResponders
{
  if (! self.notificationRespondersAreSetup)
    return;
  self.notificationRespondersAreSetup = false;

  [[NSNotificationCenter defaultCenter] removeObserver:self];
  LoggingModel* loggingModel = [ApplicationDelegate sharedDelegate].loggingModel;
  [loggingModel removeObserver:self forKeyPath:@"loggingEnabled"];
}

#pragma mark - UITableViewDataSource overrides

// -----------------------------------------------------------------------------
/// @brief UITableViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (NSInteger) numberOfSectionsInTableView:(UITableView*)tableView
{
  return MaxSection;
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
  switch (section)
  {
    case GtpSection:
      return MaxGtpSectionItem;
    case CrashReportSection:
      return MaxCrashReportSectionItem;
    case LoggingSection:
      return MaxLoggingSectionItem;
    case BugReportSection:
      if (self.bugReportSectionIsDisabled)
        return 1;
      else
        return MaxBugReportSectionItem;
    default:
      assert(0);
      break;
  }
  return 0;
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (NSString*) tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section
{
  switch (section)
  {
    case GtpSection:
      return @"GTP (Go Text Protocol)";
    case CrashReportSection:
      return @"Crash Report";
    case LoggingSection:
      return @"Application log";
    case BugReportSection:
      return @"Bug Report";
    default:
      break;
  }
  return nil;
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (NSString*) tableView:(UITableView*)tableView titleForFooterInSection:(NSInteger)section
{
  if (GtpSection == section)
    return @"Observe the flow of communication between Little Go (GTP client) and Fuego (GTP engine), or inject your own GTP commands (dangerous!).";
  else if (LoggingSection == section)
    return @"If you plan to send a bug report (see below) you should enable logging BEFORE you reproduce the error. The data collected in the log file will be sent along with the bug report and maximize the chance that the developer can fix the problem.";
  else if (BugReportSection == section)
  {
    if (self.bugReportSectionIsDisabled)
      return @"The options for reporting a bug are temporarily unavailable because the application is currently busy doing something else (e.g. computer player is thinking). If this is a computer vs. computer game, you must pause the game to be able to send a bug report.";
    else
      return @"Sending a bug report creates an email with an attached diagnostics information file. You can edit the email before you send it. If you want to send the report from your computer, generate just the file and transfer it to your computer via iTunes file sharing.\n\nIMPORTANT: Please do not send reports without a problem description! It is impossible for me to know the nature of your problem just from the file attachment. Usually I will simply ignore emails that don't contain an explanation of what the problem is.";
  }
  else
    return nil;
}

// -----------------------------------------------------------------------------
/// @brief UITableViewDataSource protocol method.
// -----------------------------------------------------------------------------
- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
  UITableViewCell* cell = nil;
  switch (indexPath.section)
  {
    case GtpSection:
    {
      cell = [TableViewCellFactory cellWithType:DefaultCellType tableView:tableView];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
      switch (indexPath.row)
      {
        case GtpLogItem:
          cell.textLabel.text = @"GTP log";
          break;
        case GtpCommandsItem:
          cell.textLabel.text = @"GTP commands";
          break;
        case GtpSettingsItem:
          cell.textLabel.text = @"Settings";
          break;
        default:
          assert(0);
          @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"invalid index path %@", indexPath] userInfo:nil];
          break;
      }
      break;
    }
    case CrashReportSection:
    {
      switch (indexPath.row)
      {
        case CrashReportSettingsItem:
        {
          cell = [TableViewCellFactory cellWithType:DefaultCellType tableView:tableView];
          cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
          cell.textLabel.text = @"Settings";
          break;
        }
        default:
        {
          assert(0);
          @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"invalid index path %@", indexPath] userInfo:nil];
          break;
        }
      }
      break;
    }
    case LoggingSection:
    {
      cell = [TableViewCellFactory cellWithType:SwitchCellType tableView:tableView];
      UISwitch* accessoryView = (UISwitch*)cell.accessoryView;
      cell.textLabel.text = @"Collect logging data";
      accessoryView.on = [ApplicationDelegate sharedDelegate].loggingModel.loggingEnabled;
      [accessoryView addTarget:self action:@selector(toggleLoggingEnabled:) forControlEvents:UIControlEventValueChanged];
      break;
    }
    case BugReportSection:
    {
      if (self.bugReportSectionIsDisabled)
      {
        cell = [TableViewCellFactory cellWithType:ActivityIndicatorCellType tableView:tableView];
        cell.textLabel.text = @"Temporarily unavailable...";
        UIActivityIndicatorView* accessoryView = (UIActivityIndicatorView*)cell.accessoryView;
        [accessoryView startAnimating];
      }
      else
      {
        cell = [TableViewCellFactory cellWithType:DefaultCellType tableView:tableView];
        cell.accessoryType = UITableViewCellAccessoryNone;
        switch (indexPath.row)
        {
          case SendBugReportItem:
            cell.textLabel.text = @"Send a bug report";
            break;
          case GenerateDiagnosticsInformationFileItem:
            cell.textLabel.text = @"Generate diagnostics information";
            break;
          default:
            assert(0);
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"invalid index path %@", indexPath] userInfo:nil];
            break;
        }
      }
      break;
    }
    default:
    {
      assert(0);
      @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"invalid index path %@", indexPath] userInfo:nil];
      break;
    }
  }
  return cell;
}

#pragma mark - UITableViewDelegate overrides

// -----------------------------------------------------------------------------
/// @brief UITableViewDelegate protocol method.
// -----------------------------------------------------------------------------
- (void) tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
  [tableView deselectRowAtIndexPath:indexPath animated:NO];

  switch (indexPath.section)
  {
    case GtpSection:
    {
      switch (indexPath.row)
      {
        case GtpLogItem:
          [self viewGtpLog];
          break;
        case GtpCommandsItem:
          [self viewCannedGtpCommands];
          break;
        case GtpSettingsItem:
          [self viewGtpSettings];
          break;
        default:
          assert(0);
          break;
      }
      break;
    }
    case CrashReportSection:
    {
      switch (indexPath.row)
      {
        case CrashReportSettingsItem:
          [self viewCrashReportSettings];
          break;
        default:
          assert(0);
          break;
      }
      break;
    }
    case BugReportSection:
    {
      if (self.bugReportSectionIsDisabled)
      {
        break;  // ignore user interaction
      }
      else
      {
        switch (indexPath.row)
        {
          case SendBugReportItem:
            [self sendBugReport];
            break;
          case GenerateDiagnosticsInformationFileItem:
            [self generateDiagnosticsInformationFile];
            break;
          default:
            assert(0);
            break;
        }
      }
      break;
    }
    default:
    {
      return;
    }
  }
}

#pragma mark - Action handlers

// -----------------------------------------------------------------------------
/// @brief Displays GtpLogViewController to allow the user to view the GTP
/// command/response log.
// -----------------------------------------------------------------------------
- (void) viewGtpLog
{
  GtpLogViewController* controller = [GtpLogViewController controller];
  [self.navigationController pushViewController:controller animated:YES];
}

// -----------------------------------------------------------------------------
/// @brief Displays GtpCommandViewController to allow the user to manage canned
/// GTP commands.
// -----------------------------------------------------------------------------
- (void) viewCannedGtpCommands
{
  GtpCommandViewController* controller = [GtpCommandViewController controller];
  [self.navigationController pushViewController:controller animated:YES];
}

// -----------------------------------------------------------------------------
/// @brief Displays GtpLogSettingsController to allow the user to view and
/// modify settings related to the GTP command/response log.
// -----------------------------------------------------------------------------
- (void) viewGtpSettings
{
  GtpLogSettingsController* controller = [GtpLogSettingsController controller];
  [self.navigationController pushViewController:controller animated:YES];
}

// -----------------------------------------------------------------------------
/// @brief Displays CrashReportingSettingsController to allow the user to view
/// and modify settings related to the crash reporting service.
// -----------------------------------------------------------------------------
- (void) viewCrashReportSettings
{
  CrashReportingSettingsController* controller = [CrashReportingSettingsController controller];
  [self.navigationController pushViewController:controller animated:YES];
}

// -----------------------------------------------------------------------------
/// @brief Triggers the workflow that allows the user to send a bug report email
/// directly from the device.
// -----------------------------------------------------------------------------
- (void) sendBugReport
{
  SendBugReportController* controller = [SendBugReportController controller];
  [controller sendBugReport:self];
}

// -----------------------------------------------------------------------------
/// @brief Generates the file with diagnostics information for transfer with
/// iTunes file sharing.
// -----------------------------------------------------------------------------
- (void) generateDiagnosticsInformationFile
{
  SendBugReportController* controller = [SendBugReportController controller];
  [controller generateDiagnosticsInformationFile];
}

// -----------------------------------------------------------------------------
/// @brief Reacts to a tap gesture on the "Enable logging" switch. Writes the
/// new value to the user defaults and immediately enables/disables logging.
// -----------------------------------------------------------------------------
- (void) toggleLoggingEnabled:(id)sender
{
  UISwitch* accessoryView = (UISwitch*)sender;
  ApplicationDelegate* appDelegate = [ApplicationDelegate sharedDelegate];
  self.ignoreLoggingEnabledModelUpdate = true;
  appDelegate.loggingModel.loggingEnabled = accessoryView.on;
  self.ignoreLoggingEnabledModelUpdate = false;
  [appDelegate setupLogging];
}

#pragma mark - Notification responders

// -----------------------------------------------------------------------------
/// @brief Responds to the #computerPlayerThinkingStarts and
/// #computerPlayerThinkingStops notifications.
// -----------------------------------------------------------------------------
- (void) computerPlayerThinkingChanged:(NSNotification*)notification
{
  [self updateBugReportSection];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreCalculationStarts notification.
// -----------------------------------------------------------------------------
- (void) goScoreCalculationStarts:(NSNotification*)notification
{
  [self updateBugReportSection];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #goScoreCalculationEnds notification.
// -----------------------------------------------------------------------------
- (void) goScoreCalculationEnds:(NSNotification*)notification
{
  [self updateBugReportSection];
}

// -----------------------------------------------------------------------------
/// @brief Responds to KVO notifications.
// -----------------------------------------------------------------------------
- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:@"loggingEnabled"])
  {
    if (self.ignoreLoggingEnabledModelUpdate)
      return;
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:LoggingEnabledItem
                                                inSection:LoggingSection];
    NSArray* indexPaths = [NSArray arrayWithObject:indexPath];
    [self.tableView reloadRowsAtIndexPaths:indexPaths
                          withRowAnimation:UITableViewRowAnimationNone];
  }
}

#pragma mark - Private helpers

// -----------------------------------------------------------------------------
/// @brief Enables or disables the features in the "Send bug report" section,
/// depending on the current state of the application.
///
/// See shouldDisableBugReportSection() for details.
// -----------------------------------------------------------------------------
- (void) updateBugReportSection
{
  bool shouldDisableBugReportSection = [self shouldDisableBugReportSection];
  if (shouldDisableBugReportSection == self.bugReportSectionIsDisabled)
    return;
  if ([NSThread currentThread] != [NSThread mainThread])
  {
    [self performSelectorOnMainThread:@selector(updateBugReportSection) withObject:nil waitUntilDone:YES];
    return;
  }
  self.bugReportSectionIsDisabled = shouldDisableBugReportSection;
  NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:BugReportSection];
  [self.tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
}

// -----------------------------------------------------------------------------
/// @brief Returns true if the features in the "Send bug report" section should
/// be disabled.
///
/// The features in question need to be disabled during long-running operations
/// taking place elsewhere in the application. In-memory objects may be in an
/// inconsistent state while these operations are in progress, therefore it is
/// not possible to generate the diagnostics information file.
// -----------------------------------------------------------------------------
- (bool) shouldDisableBugReportSection
{
  GoGame* game = [GoGame sharedGame];
  switch (game.type)
  {
    case GoGameTypeComputerVsComputer:
    {
      // In computer vs. computer games the game must be paused to enable the
      // bug report section. If we were to react only to "isComputerThinking",
      // we would constantly enable/disable the section.
      switch (game.state)
      {
        case GoGameStateGameHasStarted:
          return true;
        default:
          break;
      }
      break;
    }
    default:
    {
      if (game.isComputerThinking)
        return true;
      else
        break;
    }
  }
  if ([ApplicationDelegate sharedDelegate].uiSettingsModel.uiAreaPlayMode == UIAreaPlayModeScoring)
  {
    if (game.score.scoringInProgress)
      return true;
  }
  return false;
}

@end
