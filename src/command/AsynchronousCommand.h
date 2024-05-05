// -----------------------------------------------------------------------------
// Copyright 2013-2024 Patrick Näf (herzbube@herzbube.ch)
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
#import "Command.h"

// Library includes
#import <MBProgressHUD/MBProgressHUD.h>

// Forward declarations
@protocol AsynchronousCommandDelegate;


// -----------------------------------------------------------------------------
/// @brief The AsynchronousCommand protocol must be adopted by classes that
/// already adopt the Command protocol if they want to be executed
/// asynchronously.
// -----------------------------------------------------------------------------
@protocol AsynchronousCommand <Command>
@required
/// @brief The value of this property is set before the command is executed.
@property(nonatomic, assign) id<AsynchronousCommandDelegate> asynchronousCommandDelegate;

/// @brief Indicates whether or not the progress HUD should be displayed. If
/// the property is @e false then the command must not call any
/// AsynchronousCommandDelegate methods related to the progress HUD.
@property(nonatomic, assign) bool showProgressHUD;
@end

// -----------------------------------------------------------------------------
/// @brief The AsynchronousCommandDelegate protocol must be adopted by the
/// delegate of AsynchronousCommand.
// -----------------------------------------------------------------------------
@protocol AsynchronousCommandDelegate
/// @brief Is invoked by @a command after command execution has progressed to
/// the new completion percentage @a progress. The optional @a message refers
/// to the step that @a command will execute next.
///
/// If @a message is not nil the delegate should update the progress HUD to
/// display @a message. If @a message is nil, the delegate should not update the
/// progress HUD. This allows the command to set an initial message that remains
/// the same for the entire command execution.
- (void) asynchronousCommand:(id<AsynchronousCommand>)command didProgress:(float)progress nextStepMessage:(NSString*)message;

/// @brief May be invoked by @a command if the progress HUD should be displayed
/// with @a mode. If this is not invoked, the progress HUD will be displayed
/// using MBProgressHUDModeAnnularDeterminate.
- (void) asynchronousCommand:(id<AsynchronousCommand>)command setProgressHUDMode:(MBProgressHUDMode)mode;
@end
