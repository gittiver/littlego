// -----------------------------------------------------------------------------
// Copyright 2011-2024 Patrick Näf (herzbube@herzbube.ch)
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
@class GoVertex;
@class GoBoard;
@class GoBoardRegion;


// -----------------------------------------------------------------------------
/// @brief The GoPoint class represents the intersection of a horizontal and a
/// vertical line on the Go board. The location of the intersection is
/// identified by a GoVertex, which is used to create the GoPoint object.
///
/// @ingroup go
///
/// A GoPoint has a "stone state", denoting whether a stone has been placed on
/// the intersection, and which color the stone has. Instead of accessing the
/// technical stoneState() property, one might prefer to query a GoPoint object
/// for the same information using the more intuitive hasStone() and
/// blackStone() methods.
///
/// The liberties() method behaves differently depending on whether GoPoint is
/// occupied by a stone: If it is occupied by a stone, the method returns the
/// number of liberties of the entire stone group. If the GoPoint is not
/// occupied, the method returns the number of liberties of just that one
/// intersection.
///
/// isLegalMove() is a convenient way to check whether placing a stone on the
/// GoPoint would be legal. This includes checking for suicide moves and Ko
/// situations.
// -----------------------------------------------------------------------------
@interface GoPoint : NSObject <NSSecureCoding>
{
}

+ (GoPoint*) pointAtVertex:(GoVertex*)vertex onBoard:(GoBoard*)board;
- (bool) hasStone;
- (bool) blackStone;
- (int) liberties;
- (bool) isEqualToPoint:(GoPoint*)point;
- (NSArray*) neighbourRegionsWithColor:(enum GoColor)color;
- (void) prepareForDealloc;

/// @brief Identifies the location of the intersection that the GoPoint
/// represents.
@property(nonatomic, retain) GoVertex* vertex;
/// @brief The GoBoard object that the GoPoint is associated with.
@property(nonatomic, assign) GoBoard* board;
@property(nonatomic, assign, readonly) GoPoint* left;
@property(nonatomic, assign, readonly) GoPoint* right;
@property(nonatomic, assign, readonly) GoPoint* above;
@property(nonatomic, assign, readonly) GoPoint* below;
@property(nonatomic, retain, readonly) NSArray* neighbours;
@property(nonatomic, assign, readonly) GoPoint* next;
@property(nonatomic, assign, readonly) GoPoint* previous;
/// @brief Is true if the GoPoint is a star point.
@property(nonatomic, assign, getter=isStarPoint) bool starPoint;
/// @brief Denotes whether a stone has been placed on the intersection that the
/// GoPoint represents, and which color the stone has.
@property(nonatomic, assign) enum GoColor stoneState;
/// @brief The score assigned to this point by the most recent territory
/// statistics evaluation.
@property(nonatomic, assign) float territoryStatisticsScore;
/// @brief The region that the GoPoint belongs to. Is never nil.
///
/// You should never need to change this property by yourself. Instead invoke
/// methods in GoBoardRegion such as GoBoardRegion::addPoint:() or
/// GoBoardRegion::removePoint:().
@property(nonatomic, retain) GoBoardRegion* region;

@end
