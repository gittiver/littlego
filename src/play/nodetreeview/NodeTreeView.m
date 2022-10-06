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
#import "NodeTreeView.h"
#import "NodeTreeTileView.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for NodeTreeView.
// -----------------------------------------------------------------------------
@interface NodeTreeView()
@end


@implementation NodeTreeView

#pragma mark - Initialization and deallocation

// -----------------------------------------------------------------------------
/// @brief Initializes a NodeTreeView object with frame rectangle @a rect.
///
/// @note This is the designated initializer of NodeTreeView.
// -----------------------------------------------------------------------------
- (id) initWithFrame:(CGRect)rect
{
  // Call designated initializer of superclass (TiledScrollView)
  self = [super initWithFrame:rect tileViewClass:[NodeTreeTileView class]];
  if (! self)
    return nil;

  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this NodeTreeView object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [super dealloc];
}

@end
