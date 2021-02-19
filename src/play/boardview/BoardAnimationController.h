// -----------------------------------------------------------------------------
// Copyright 2021 Patrick Näf (herzbube@herzbube.ch)
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


// Forward declarations
@class BoardView;


// -----------------------------------------------------------------------------
/// @brief The BoardAnimationController class is responsible for initiating and
/// managing animations on the Go board.
///
/// BoardAnimationController reacts to events (e.g. notifications sent because
/// of user interaction) and initiates the appropriate animation.
///
/// BoardAnimationController realizes the animations by temporarily adding a
/// subview to BoardView whose properties are then animated. The subview is
/// configured so that the user cannot interact with it (e.g. gestures do not
/// register on it but still go to BoardView).
///
/// BoardAnimationController sends notifications that indicate the start and
/// end of an animation so that other parts of the system can react accordingly.
// -----------------------------------------------------------------------------
@interface BoardAnimationController : NSObject
{
}

@property(nonatomic, retain) BoardView* boardView;

@end
