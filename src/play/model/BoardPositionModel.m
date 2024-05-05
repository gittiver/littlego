// -----------------------------------------------------------------------------
// Copyright 2012-2024 Patrick Näf (herzbube@herzbube.ch)
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
#import "BoardPositionModel.h"


@implementation BoardPositionModel

// -----------------------------------------------------------------------------
/// @brief Initializes a BoardPositionModel object with user defaults data.
///
/// @note This is the designated initializer of BoardPositionModel.
// -----------------------------------------------------------------------------
- (id) init
{
  // Call designated initializer of superclass (NSObject)
  self = [super init];
  if (! self)
    return nil;
  self.discardFutureNodesAlert = discardFutureNodesAlertDefault;
  self.markNextMove = markNextMoveDefault;
  self.discardMyLastMove = discardMyLastMoveDefault;
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Initializes default values in this model with user defaults data.
// -----------------------------------------------------------------------------
- (void) readUserDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSDictionary* dictionary = [userDefaults dictionaryForKey:boardPositionKey];
  self.discardFutureNodesAlert = [[dictionary valueForKey:discardFutureNodesAlertKey] boolValue];
  self.markNextMove = [[dictionary valueForKey:markNextMoveKey] boolValue];
  self.discardMyLastMove = [[dictionary valueForKey:discardMyLastMoveKey] boolValue];
}

// -----------------------------------------------------------------------------
/// @brief Writes current values in this model to the user default system's
/// application domain.
// -----------------------------------------------------------------------------
- (void) writeUserDefaults
{
  NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
  [dictionary setValue:[NSNumber numberWithBool:self.discardFutureNodesAlert] forKey:discardFutureNodesAlertKey];
  [dictionary setValue:[NSNumber numberWithBool:self.markNextMove] forKey:markNextMoveKey];
  [dictionary setValue:[NSNumber numberWithBool:self.discardMyLastMove] forKey:discardMyLastMoveKey];
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setObject:dictionary forKey:boardPositionKey];
}

@end
