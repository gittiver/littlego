// -----------------------------------------------------------------------------
// Copyright 2014-2024 Patrick Näf (herzbube@herzbube.ch)
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
#import "../../ui/TiledScrollView.h"
#import "BoardViewIntersection.h"

// Forward declarations
@class GoPoint;


// -----------------------------------------------------------------------------
/// @brief The BoardView class subclasses TiledScrollView to add cross-hair
/// handling.
// -----------------------------------------------------------------------------
@interface BoardView : TiledScrollView
{
}

- (BoardViewIntersection) intersectionNear:(CGPoint)coordinates;
- (void) moveCrossHairToPoint:(GoPoint*)point;
- (void) moveCrossHairWithStoneTo:(GoPoint*)point
                      isLegalMove:(bool)isLegalMove
                  isIllegalReason:(enum GoMoveIsIllegalReason)illegalReason;
- (void) moveCrossHairWithSymbol:(enum GoMarkupSymbol)symbol
                         toPoint:(GoPoint*)point;
- (void) moveMarkupConnection:(enum GoMarkupConnection)connection
               withStartPoint:(GoPoint*)startPoint
                   toEndPoint:(GoPoint*)endPoint;
- (void) moveCrossHairWithLabel:(enum GoMarkupLabel)label
                      labelText:(NSString*)labelText
                        toPoint:(GoPoint*)point;
- (void) updateSelectionRectangleFromPoint:(GoPoint*)fromPoint
                                   toPoint:(GoPoint*)toPoint;

@end
