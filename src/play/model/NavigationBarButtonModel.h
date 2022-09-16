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


// -----------------------------------------------------------------------------
/// @brief The NavigationBarButtonModel class manages UIBarButtonItems objects
/// that are displayed in a UINavigationBar and that represent game actions.
// -----------------------------------------------------------------------------
@interface NavigationBarButtonModel : NSObject
{
}

- (void) updateVisibleGameActions;
- (void) updateVisibleGameActionsWithVisibleStates:(NSDictionary*)visibleStates;
- (void) updateIconOfGameAction:(enum GameAction)gameAction;

@property(nonatomic, retain, readonly) NSDictionary* gameActionButtons;
@property(nonatomic, retain, readonly) NSArray* buttonOrderList;
@property(nonatomic, retain, readonly) NSArray* visibleGameActions;

@end
