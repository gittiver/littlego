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
#import "PlayRootViewController.h"
#import "GameActionManager.h"
#import "../../ui/OrientationChangeNotifyingView.h"


// -----------------------------------------------------------------------------
/// @brief The PlayRootViewControllerPhoneAndPad class is the root view
/// controller of the #UIAreaPlay for both #UITypePhone and #UITypePad. It is
/// used in both Portrait and Landscape interface orientations.
///
/// The PlayRootViewController class method playRootViewController() should be
/// used to create a PlayRootViewControllerPhoneAndPads instance.
// -----------------------------------------------------------------------------
@interface PlayRootViewControllerPhoneAndPad
  : PlayRootViewController <GameActionManagerUIDelegate,
                            OrientationChangeNotifyingViewDelegate>
{
}

- (id) initWithUiType:(enum UIType)uiType;

@end
