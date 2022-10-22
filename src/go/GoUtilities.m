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
#import "GoUtilities.h"
#import "GoBoard.h"
#import "GoBoardPosition.h"
#import "GoBoardRegion.h"
#import "GoGame.h"
#import "GoGameRules.h"
#import "GoMove.h"
#import "GoNode.h"
#import "GoNodeAnnotation.h"
#import "GoNodeModel.h"
#import "GoPoint.h"
#import "GoVertex.h"
#import "GoZobristTable.h"


@implementation GoUtilities

// -----------------------------------------------------------------------------
/// @brief Moves @a thePoint to a new GoBoardRegion in response to a change of
/// GoPoint.stoneState.
///
/// @a thePoint's stone state already must have its new value at the time this
/// method is invoked.
///
/// Effects of this method are:
/// - @a thePoint is removed from its old GoBoardRegion
/// - @a thePoint is added either to an existing GoBoardRegion (if one of the
///   neighbours of @a thePoint has the same GoPoint.stoneState), or to a new
///   GoBoardRegion (if all neighbours have a different GoPoint.stoneState)
/// - @a thePoint's old GoBoardRegion may become fragmented if @a thePoint
///   has been the only link between two or more sub-regions
/// - @a thePoint's new GoBoardRegion may merge with other regions if
///   @a thePoint joins them together
// -----------------------------------------------------------------------------
+ (void) movePointToNewRegion:(GoPoint*)thePoint
{
  // Step 1: Remove point from old region
  // Note: We must retain/autorelease to make sure that oldRegion survives
  // invocation of removePoint:() one line further down. If we don't retain
  // and thePoint is the last point of oldRegion, invoking removePoint:() will
  // cause thePoint's reference to oldRegion to be removed, which in turn will
  // cause oldRegion's retain count to drop to zero, deallocating it.
  GoBoardRegion* oldRegion = [[thePoint.region retain] autorelease];
  [oldRegion removePoint:thePoint];  // possible side-effect: oldRegion might be
                                     // split into multiple GoBoardRegion objects

  // Step 2: Attempt to add the point to the same region as one of its
  // neighbours. At the same time, merge regions if they can be joined.
  GoBoardRegion* newRegion = nil;
  for (GoPoint* neighbour in thePoint.neighbours)
  {
    // Do not consider the neighbour if the stone states do not match (stone
    // state also includes stone color)
    if (neighbour.stoneState != thePoint.stoneState)
      continue;
    if (! newRegion)
    {
      // Join the region of one of the neighbours
      newRegion = neighbour.region;
      [newRegion addPoint:thePoint];
    }
    else
    {
      // The stone has already joined a neighbouring region
      // -> now check if entire regions can be merged
      GoBoardRegion* neighbourRegion = neighbour.region;
      if (neighbourRegion != newRegion)
        [newRegion joinRegion:neighbourRegion];
    }
  }

  // Step 3: Still no region? The point forms its own new region!
  if (! newRegion)
    [GoBoardRegion regionWithPoint:thePoint];
}

// -----------------------------------------------------------------------------
/// @brief Returns an (unordered) list of NSString objects that denote vertices
/// for the specified @a handicap and @a boardSize.
///
/// For board sizes greater than 7x7, @a handicap must be between 2 and 9. For
/// board size 7x7, @a handicap must be between 2 and 4. The limits are
/// inclusive.
///
/// The handicap positions returned by this method correspond to those specified
/// in section 4.1.1 of the GTP v2 specification.
/// https://www.lysator.liu.se/~gunnar/gtp/gtp2-spec-draft2/gtp2-spec.html#sec:fixed-handicap-placement
///
/// Handicap stone distribution for handicaps 1-5:
/// @verbatim
/// 3   2
///   5
/// 1   4
/// @endverbatim
///
/// Handicap stone distribution for handicaps 6-7:
/// @verbatim
/// 3   2
/// 5 7 6
/// 1   4
/// @endverbatim
///
/// Handicap stone distribution for handicaps 8-9:
/// @verbatim
/// 3 8 2
/// 5 9 6
/// 1 7 4
/// @endverbatim
// -----------------------------------------------------------------------------
+ (NSArray*) verticesForHandicap:(int)handicap boardSize:(enum GoBoardSize)boardSize
{
  static const int numberOfBoardSizes = (GoBoardSizeMax - GoBoardSizeMin) / 2 + 1;
  static const int maxHandicaps[numberOfBoardSizes] = {4, 9, 9, 9, 9, 9, 9};
  static const int edgeDistances[numberOfBoardSizes] = {3, 3, 3, 4, 4, 4, 4};

  NSMutableArray* handicapVertices = [NSMutableArray arrayWithCapacity:0];
  if (0 == handicap)
    return handicapVertices;

  int boardSizeArrayIndex = (boardSize - GoBoardSizeMin) / 2;
  if (handicap < 2 || handicap > maxHandicaps[boardSizeArrayIndex])
  {
    NSString* errorMessage = [NSString stringWithFormat:@"Specified handicap %d is out of range for GoBoardSize %d", handicap, boardSize];
    DDLogError(@"%@: %@", self, errorMessage);
    NSException* exception = [NSException exceptionWithName:NSRangeException
                                                     reason:errorMessage
                                                   userInfo:nil];
    @throw exception;
  }

  int edgeDistance = edgeDistances[boardSizeArrayIndex];
  int lineClose = edgeDistance;
  int lineFar = boardSize - edgeDistance + 1;
  int lineMiddle = lineClose + ((lineFar - lineClose) / 2);

  for (int handicapIter = 1; handicapIter <= handicap; ++handicapIter)
  {
    struct GoVertexNumeric numericVertex;
    switch (handicapIter)
    {
      case 1:
      {
        numericVertex.x = lineClose;
        numericVertex.y = lineClose;
        break;
      }
      case 2:
      {
        numericVertex.x = lineFar;
        numericVertex.y = lineFar;
        break;
      }
      case 3:
      {
        numericVertex.x = lineClose;
        numericVertex.y = lineFar;
        break;
      }
      case 4:
      {
        numericVertex.x = lineFar;
        numericVertex.y = lineClose;
        break;
      }
      case 5:
      {
        if (handicapIter == handicap)
        {
          numericVertex.x = lineMiddle;
          numericVertex.y = lineMiddle;
        }
        else
        {
          numericVertex.x = lineClose;
          numericVertex.y = lineMiddle;
        }
        break;
      }
      case 6:
      {
        numericVertex.x = lineFar;
        numericVertex.y = lineMiddle;
        break;
      }
      case 7:
      {
        if (handicapIter == handicap)
        {
          numericVertex.x = lineMiddle;
          numericVertex.y = lineMiddle;
        }
        else
        {
          numericVertex.x = lineMiddle;
          numericVertex.y = lineClose;
        }
        break;
      }
      case 8:
      {
        numericVertex.x = lineMiddle;
        numericVertex.y = lineFar;
        break;
      }
      case 9:
      {
        numericVertex.x = lineMiddle;
        numericVertex.y = lineMiddle;
        break;
      }
      default:
      {
        DDLogError(@"%@: Unsupported handicap %d", [self class], handicapIter);
        assert(0);
        numericVertex.x = -1;
        numericVertex.y = -1;
        break;
      }
    }
    GoVertex* vertex = [GoVertex vertexFromNumeric:numericVertex];
    [handicapVertices addObject:vertex.string];
  }

  return handicapVertices;
}

// -----------------------------------------------------------------------------
/// @brief Returns an (unordered) list of GoPoint objects for the specified
/// @a handicap and board associated with @a game.
///
/// See verticesForHandicap:boardSize:() for details.
// -----------------------------------------------------------------------------
+ (NSArray*) pointsForHandicap:(int)handicap inGame:(GoGame*)game
{
  GoBoard* board = game.board;
  if (! board)
  {
    NSString* errorMessage = @"No GoBoard object associated with specified GoGame";
    DDLogError(@"%@: %@", self, errorMessage);
    NSException* exception = [NSException exceptionWithName:NSGenericException
                                                     reason:errorMessage
                                                   userInfo:nil];
    @throw exception;
  }

  NSMutableArray* handicapPoints = [NSMutableArray arrayWithCapacity:0];
  NSArray* handicapVertices = [GoUtilities verticesForHandicap:handicap boardSize:board.size];
  for (NSString* vertex in handicapVertices)
  {
    GoPoint* point = [board pointAtVertex:vertex];
    [handicapPoints addObject:point];
  }
  return handicapPoints;
}

// -----------------------------------------------------------------------------
/// @brief Returns the maximum handicap for the specified @a boardSize.
// -----------------------------------------------------------------------------
+ (int) maximumHandicapForBoardSize:(enum GoBoardSize)boardSize
{
  switch (boardSize)
  {
    case GoBoardSize7:
      return 4;
    default:
      return 9;
  }
}

// -----------------------------------------------------------------------------
/// @brief Assuming that alternating play is desired, returns the player whose
/// turn it is after @a move was played. If @a move is nil, returns the player
/// who plays first in @a game (after taking the setup player or handicap into
/// consideration).
// -----------------------------------------------------------------------------
+ (GoPlayer*) playerAfter:(GoMove*)move inGame:(GoGame*)game
{
  if (! move)
  {
    enum GoColor setupFirstMoveColor = game.setupFirstMoveColor;
    if (setupFirstMoveColor == GoColorBlack)
    {
      return game.playerBlack;
    }
    else if (setupFirstMoveColor == GoColorWhite)
    {
      return game.playerWhite;
    }
    else
    {
      if (0 == game.handicapPoints.count)
        return game.playerBlack;
      else
        return game.playerWhite;
    }
  }
  else if (move.player == game.playerBlack)
    return game.playerWhite;
  else
    return game.playerBlack;
}

// -----------------------------------------------------------------------------
/// @brief Returns an (unordered) list of GoPoint objects whose intersections
/// are located in the rectangle delimited by @a pointA and @a pointB. The
/// points that are returned are taken from the GoBoard instance associated with
/// @a game.
// -----------------------------------------------------------------------------
+ (NSArray*) pointsInRectangleDelimitedByCornerPoint:(GoPoint*)pointA
                                 oppositeCornerPoint:(GoPoint*)pointB
                                              inGame:(GoGame*)game
{
  if (! pointA || ! pointB)
  {
    NSString* errorMessage = @"Either one or both of the delimiting GoPoint objects not specified";
    DDLogError(@"%@: %@", self, errorMessage);
    NSException* exception = [NSException exceptionWithName:NSInvalidArgumentException
                                                     reason:errorMessage
                                                   userInfo:nil];
    @throw exception;
  }
  GoBoard* board = game.board;
  if (! board)
  {
    NSString* errorMessage = @"No GoBoard object associated with specified GoGame";
    DDLogError(@"%@: %@", self, errorMessage);
    NSException* exception = [NSException exceptionWithName:NSGenericException
                                                     reason:errorMessage
                                                   userInfo:nil];
    @throw exception;
  }

  struct GoVertexNumeric numericVertexA = pointA.vertex.numeric;
  struct GoVertexNumeric numericVertexB = pointB.vertex.numeric;
  struct GoVertexNumeric numericVertexBottomLeft;
  numericVertexBottomLeft.x = MIN(numericVertexA.x, numericVertexB.x);
  numericVertexBottomLeft.y = MIN(numericVertexA.y, numericVertexB.y);
  struct GoVertexNumeric numericVertexTopRight;
  numericVertexTopRight.x = MAX(numericVertexA.x, numericVertexB.x);
  numericVertexTopRight.y = MAX(numericVertexA.y, numericVertexB.y);

  NSMutableArray* pointsInRectangle = [NSMutableArray arrayWithCapacity:0];
  struct GoVertexNumeric numericVertexIteration = numericVertexBottomLeft;
  while (numericVertexIteration.y <= numericVertexTopRight.y)
  {
    while (numericVertexIteration.x <= numericVertexTopRight.x)
    {
      GoVertex* vertexIteration = [GoVertex vertexFromNumeric:numericVertexIteration];
      GoPoint* point = [board pointAtVertex:vertexIteration.string];
      [pointsInRectangle addObject:point];
      numericVertexIteration.x++;
    }
    numericVertexIteration.x = numericVertexBottomLeft.x;
    numericVertexIteration.y++;
  }
  return pointsInRectangle;
}

// -----------------------------------------------------------------------------
/// @brief Returns an (unordered) list of GoPoint objects whose intersections
/// are located in the same row as @a point. @a point is included in the
/// result.
// -----------------------------------------------------------------------------
+ (NSArray*) pointsInRowWithPoint:(GoPoint*)point
{
  if (! point)
  {
    NSString* errorMessage = @"pointsInRowWithPoint: failed: GoPoint object not specified";
    DDLogError(@"%@: %@", self, errorMessage);
    NSException* exception = [NSException exceptionWithName:NSInvalidArgumentException
                                                     reason:errorMessage
                                                   userInfo:nil];
    @throw exception;
  }

  NSMutableArray* pointsInRow = [NSMutableArray arrayWithObject:point];

  for (GoPoint* leftNeighbour = point.left; leftNeighbour; leftNeighbour = leftNeighbour.left)
    [pointsInRow addObject:leftNeighbour];

  for (GoPoint* rightNeighbour = point.right; rightNeighbour; rightNeighbour = rightNeighbour.right)
    [pointsInRow addObject:rightNeighbour];

  return pointsInRow;
}

// -----------------------------------------------------------------------------
/// @brief Returns an (unordered) list of GoPoint objects whose intersections
/// are located in the same column as @a point. @a point is included in the
/// result.
// -----------------------------------------------------------------------------
+ (NSArray*) pointsInColumnWithPoint:(GoPoint*)point
{
  if (! point)
  {
    NSString* errorMessage = @"pointsInColumnWithPoint: failed: GoPoint object not specified";
    DDLogError(@"%@: %@", self, errorMessage);
    NSException* exception = [NSException exceptionWithName:NSInvalidArgumentException
                                                     reason:errorMessage
                                                   userInfo:nil];
    @throw exception;
  }

  NSMutableArray* pointsInColumn = [NSMutableArray arrayWithObject:point];

  for (GoPoint* aboveNeighbour = point.above; aboveNeighbour; aboveNeighbour = aboveNeighbour.above)
    [pointsInColumn addObject:aboveNeighbour];

  for (GoPoint* belowNeighbour = point.below; belowNeighbour; belowNeighbour = belowNeighbour.below)
    [pointsInColumn addObject:belowNeighbour];

  return pointsInColumn;
}

// -----------------------------------------------------------------------------
/// @brief Returns an (unordered) list of GoPoint objects that exist in both
/// @a firstArray and @a secondArray.
///
/// Assuming that both @a firstArray and @a secondArray contain GoPoint objects
/// that define a rectangle (e.g. returned by
/// pointsInRectangleDelimitedByCornerPoint:oppositeCornerPoint:inGame:()),
/// this method returns the intersection of the two rectangles.
// -----------------------------------------------------------------------------
+ (NSArray*) pointsInBothFirstArray:(NSArray*)firstArray
                     andSecondArray:(NSArray*)secondArray
{
  NSMutableArray* pointsInBothArrays = [NSMutableArray array];

  for (GoPoint* point in firstArray)
  {
    if ([secondArray containsObject:point])
      [pointsInBothArrays addObject:point];
  }

  return pointsInBothArrays;
}

// -----------------------------------------------------------------------------
/// @brief Returns the default komi value for the combination of @a handicap and
/// @a scoringSystem.
///
/// Raises an @e NSInvalidArgumentException if the combination of @a handicap
/// and @a scoringSystem is not recognized.
// -----------------------------------------------------------------------------
+ (double) defaultKomiForHandicap:(int)handicap scoringSystem:(enum GoScoringSystem)scoringSystem
{
  if (handicap > 0)
    return 0.5;

  switch (scoringSystem)
  {
    case GoScoringSystemAreaScoring:
    {
      return gDefaultKomiAreaScoring;
    }
    case GoScoringSystemTerritoryScoring:
    {
      return gDefaultKomiTerritoryScoring;
    }
    default:
    {
      NSString* errorMessage = [NSString stringWithFormat:@"Unable to determine default komi, unknown scoring system %d", scoringSystem];
      DDLogError(@"%@: %@", self, errorMessage);
      NSException* exception = [NSException exceptionWithName:NSInvalidArgumentException
                                                       reason:errorMessage
                                                     userInfo:nil];
      @throw exception;
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief Returns a newly allocated GoGameRules object that contains rules for
/// which @a ruleset is a shorthand.
///
/// Raises an @e NSInvalidArgumentException if @a ruleset is not recognized.
// -----------------------------------------------------------------------------
+ (GoGameRules*) rulesForRuleset:(enum GoRuleset)ruleset
{
  GoGameRules* rules = [[[GoGameRules alloc] init] autorelease];
  switch (ruleset)
  {
    case GoRulesetAGA:
    {
      rules.koRule = GoKoRuleSuperkoSituational;
      rules.scoringSystem = GoScoringSystemAreaScoring;
      rules.lifeAndDeathSettlingRule = GoLifeAndDeathSettlingRuleTwoPasses;
      rules.disputeResolutionRule = GoDisputeResolutionRuleAlternatingPlay;
      rules.fourPassesRule = GoFourPassesRuleFourPassesEndTheGame;
      break;
    }
    case GoRulesetIGS:
    {
      rules.koRule = GoKoRuleSimple;
      rules.scoringSystem = GoScoringSystemTerritoryScoring;
      rules.lifeAndDeathSettlingRule = GoLifeAndDeathSettlingRuleThreePasses;
      rules.disputeResolutionRule = GoDisputeResolutionRuleAlternatingPlay;
      rules.fourPassesRule = GoFourPassesRuleFourPassesHaveNoSpecialMeaning;
      break;
    }
    case GoRulesetChinese:
    {
      rules.koRule = GoKoRuleSuperkoPositional;
      rules.scoringSystem = GoScoringSystemAreaScoring;
      rules.lifeAndDeathSettlingRule = GoLifeAndDeathSettlingRuleTwoPasses;
      rules.disputeResolutionRule = GoDisputeResolutionRuleNonAlternatingPlay;
      rules.fourPassesRule = GoFourPassesRuleFourPassesHaveNoSpecialMeaning;
      break;
    }
    case GoRulesetJapanese:
    {
      rules.koRule = GoKoRuleSimple;
      rules.scoringSystem = GoScoringSystemTerritoryScoring;
      rules.lifeAndDeathSettlingRule = GoLifeAndDeathSettlingRuleTwoPasses;
      rules.disputeResolutionRule = GoDisputeResolutionRuleNonAlternatingPlay;
      rules.fourPassesRule = GoFourPassesRuleFourPassesHaveNoSpecialMeaning;
      break;
    }
    case GoRulesetLittleGo:
    {
      rules.koRule = GoKoRuleDefault;
      rules.scoringSystem = gDefaultScoringSystem;
      rules.lifeAndDeathSettlingRule = GoLifeAndDeathSettlingRuleDefault;
      rules.disputeResolutionRule = GoDisputeResolutionRuleDefault;
      rules.fourPassesRule = GoFourPassesRuleDefault;
      break;
    }
    default:
    {
      NSString* errorMessage = [NSString stringWithFormat:@"Unable to determine GoGameRules, unknown ruleset %d", ruleset];
      DDLogError(@"%@: %@", self, errorMessage);
      NSException* exception = [NSException exceptionWithName:NSInvalidArgumentException
                                                       reason:errorMessage
                                                     userInfo:nil];
      @throw exception;
    }
  }
  return rules;
}

// -----------------------------------------------------------------------------
/// @brief Returns the ruleset that best describes the rules in @a rules.
/// Returns #GoRulesetCustom if no ruleset fits.
// -----------------------------------------------------------------------------
+ (enum GoRuleset) rulesetForRules:(GoGameRules*)rules
{
  for (enum GoRuleset ruleset = GoRulesetMin; ruleset <= GoRulesetMax; ++ruleset)
  {
    GoGameRules* rulesForRuleset = [GoUtilities rulesForRuleset:ruleset];
    if (rules.koRule != rulesForRuleset.koRule)
      continue;
    else if (rules.scoringSystem != rulesForRuleset.scoringSystem)
      continue;
    else if (rules.lifeAndDeathSettlingRule != rulesForRuleset.lifeAndDeathSettlingRule)
      continue;
    else if (rules.disputeResolutionRule != rulesForRuleset.disputeResolutionRule)
      continue;
    else if (rules.fourPassesRule != rulesForRuleset.fourPassesRule)
      continue;
    return ruleset;
  }
  return GoRulesetCustom;
}

// -----------------------------------------------------------------------------
/// @brief Returns the color that is the alternating (i.e. opposite) color of
/// @a color.
///
/// Raises an @e NSInvalidArgumentException if @a color is neither #GoColorBlack
/// nor #GoColorWhite.
// -----------------------------------------------------------------------------
+ (enum GoColor) alternatingColorForColor:(enum GoColor)color
{
  switch (color)
  {
    case GoColorBlack:
      return GoColorWhite;
    case GoColorWhite:
      return GoColorBlack;
    default:
      break;
  }
  NSString* errorMessage = [NSString stringWithFormat:@"Unable to determine alternating color for color %d", color];
  DDLogError(@"%@: %@", self, errorMessage);
  NSException* exception = [NSException exceptionWithName:NSInvalidArgumentException
                                                   reason:errorMessage
                                                 userInfo:nil];
  @throw exception;
}

// -----------------------------------------------------------------------------
/// @brief Returns true if @a game is in a state that counts as "resumed play".
/// Returns false if @a game is not in "resumed play" state.
// -----------------------------------------------------------------------------
+ (bool) isGameInResumedPlayState:(GoGame*)game
{
  // Very Special Case: GoLifeAndDeathSettlingRuleThreePasses is used to
  // implement IGS rules. When this rule is active, play can only be resumed by
  // discarding the third pass move. This does not count as "resumed play" in
  // the sense understood and implemented by this app.
  if (GoLifeAndDeathSettlingRuleThreePasses == game.rules.lifeAndDeathSettlingRule)
    return false;

  // Obviously, the game must be in progress
  if (GoGameStateGameHasStarted != game.state)
    return false;

  // Resumed play is not possible if no moves were played yet
  GoNode* nodeWithMostRecentMove = [GoUtilities nodeWithMostRecentMove:game.boardPosition.currentNode];
  if (! nodeWithMostRecentMove)
    return false;

  // Resumed play is only possible if the user views a board position that
  // reflects the position after the last move was played. If this happens to
  // be also the last node of the game then the user will be able to continue
  // to play immediately. If there are other nodes (without moves) then the user
  // will have to discard those nodes, or change board position to the last
  // node of the game.
  GoMove* mostRecentMove = nodeWithMostRecentMove.goMove;
  bool mostRecentMoveIsLastMove = (mostRecentMove == game.lastMove);
  if (! mostRecentMoveIsLastMove)
    return false;

  // An even number of consecutive pass moves must have been made at the end of
  // the game. If GoFourPassesRuleFourPassesEndTheGame is in effect it will
  // cause the game to end after 4 passes, so that's not a problem we have to
  // deal with here.
  int numberOfConsecutivePassMoves = 0;
  GoMove* potentialPassMove = mostRecentMove;
  while (potentialPassMove && GoMoveTypePass == potentialPassMove.type)
  {
    ++numberOfConsecutivePassMoves;
    potentialPassMove = potentialPassMove.previous;
  }
  if (0 == numberOfConsecutivePassMoves)
    return false;
  if (numberOfConsecutivePassMoves % 2 != 0)
    return false;

  return true;
}

// -----------------------------------------------------------------------------
/// @brief Returns true if @a game has ended and its remaining state allows play
/// to be resumed in order to settle life & death disputes. Returns false if the
/// state of @a game does not allow play to be resumed.
// -----------------------------------------------------------------------------
+ (bool) shouldAllowResumePlay:(GoGame*)game
{
  // Obviously, play can only be resumed if the game has ended
  if (GoGameStateGameHasEnded != game.state)
    return false;

  // Only if the game ended after two passes can play be resumed. In all other
  // cases the user has to perform a different action (e.g. "undo resign",
  // "discard last move") to resume play. Whether or not such an action is
  // available in the UI depends on the circumstances (e.g. in a Game Center
  // game moves typically cannot be discarded).
  if (GoGameHasEndedReasonTwoPasses != game.reasonForGameHasEnded)
    return false;

  // Resuming play for computer vs. computer games does not make sense - the
  // computer player does not understand "life & death disputes" and in all
  // probability will merely continue to play passes
  if (GoGameTypeComputerVsComputer == game.type)
    return false;

  // If the user is not viewing a board position that reflects the position
  // after the last move was played, we assume that she is not interested in
  // resuming play, so we don't allow it. More importantly: We MUST not resume
  // play in case GoDisputeResolutionRuleNonAlternatingPlay is active, because:
  // 1) The client would probably have to display an alert that lets the user
  //    choose the side to play first after play is resumed. Such an alert is
  //    probably inappropriate since at the moment the user is viewing an old
  //    board position.
  // 2) The alert would have to base its content on the current value of
  //    game.nextMoveColor, which would be wrong for the purpose of play
  //    resumption because at the moment game.nextMoveColor reflects the side to
  //    play next after the CURRENT board position, not after the LAST board
  //    position.
  // 3) In response to the alert, the value of game.nextMoveColor might have to
  //    be changed which, again, is inappropriate because game.nextMoveColor is
  //    tied to the CURRENT board position, not the board position with the LAST
  //    move.
  if ([GoUtilities nodeWithNextMoveExists:game.boardPosition.currentNode inCurrentGameVariation:game])
    return false;

  return true;
}

// -----------------------------------------------------------------------------
/// @brief Returns a single string that consists of a space separated list of
/// vertices, one for each GoPoint object in @a points. Vertices appear in the
/// returned string in no particular order. Returns an empty string if @a points
/// has no elements.
///
/// This method is useful to generate the arguments for certain GTP commands
/// (e.g. "set_free_handicap").
// -----------------------------------------------------------------------------
+ (NSString*) verticesStringForPoints:(NSArray*)points
{
  NSString* verticesString = @"";
  bool firstVertice = true;
  for (GoPoint* point in points)
  {
    if (firstVertice)
      firstVertice = false;
    else
      verticesString = [verticesString stringByAppendingString:@" "];
    verticesString = [verticesString stringByAppendingString:point.vertex.string];
  }
  return verticesString;
}

// -----------------------------------------------------------------------------
/// @brief Recalculates all Zobrist hashes of the specified game.
///
/// GoZobristTable is not archived when a game is archived, instead a new
/// GoZobristTable object with random values is created each time when a game
/// is unarchived. Zobrist hashes created by the previous GoZobristTable object
/// are thus invalid and must be re-calculated when a game is unarchived.
/// This method performs the necessary re-calculations.
///
/// @note Because Zobrist hashes would be invalid after unarchiving, they are
/// not even archived in the first place. This has the benefit that the archive
/// becomes smaller.
// -----------------------------------------------------------------------------
+ (void) recalculateZobristHashes:(GoGame*)game
{
  GoZobristTable* zobristTable = game.board.zobristTable;

  game.zobristHashAfterHandicap = [zobristTable hashForHandicapStonesInGame:game];

  NSMutableArray* stack = [NSMutableArray array];
  GoNode* currentNode = game.nodeModel.rootNode;
  while (true)
  {
    while (currentNode)
    {
      currentNode.zobristHash = [zobristTable hashForNode:currentNode inGame:game];

      [stack addObject:currentNode];

      currentNode = currentNode.firstChild;
    }

    if (stack.count > 0)
    {
      currentNode = stack.lastObject;
      [stack removeLastObject];

      currentNode = currentNode.nextSibling;
    }
    else
    {
      // We're done
      break;
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief Relinks all moves of the specified game. The source is the
/// GoNodeModel contained by @a game.
///
/// The previous move of a GoMove is not archived when a game is archived
/// to avoid a stack overflow when the game contains a large number of moves.
// -----------------------------------------------------------------------------
+ (void) relinkMoves:(GoGame*)game
{
  NSMutableArray* stack = [NSMutableArray array];
  NSNull* nullValue = [NSNull null];

  GoNode* currentNode = game.nodeModel.rootNode;
  GoMove* previousMove = nil;

  while (true)
  {
    while (currentNode)
    {
      GoMove* move = currentNode.goMove;
      if (move)
      {
        [move setUnarchivedPreviousMove:previousMove];
        previousMove = move;
      }

      [stack addObject:@[currentNode, previousMove ? previousMove : nullValue]];

      currentNode = currentNode.firstChild;
    }

    if (stack.count > 0)
    {
      NSArray* tuple = stack.lastObject;
      [stack removeLastObject];

      currentNode = tuple.firstObject;
      previousMove = tuple.lastObject;
      if ((id)previousMove == nullValue)
        previousMove = nil;

      currentNode = currentNode.nextSibling;
    }
    else
    {
      // We're done
      break;
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief Examines @a node and its ancestors. Returns the first node found that
/// contains a move. Returns @a node if it contains a move. Returns @e nil if
/// no move can be found.
// -----------------------------------------------------------------------------
+ (GoNode*) nodeWithMostRecentMove:(GoNode*)node
{
  while (node)
  {
    if (node.goMove)
      return node;
    node = node.parent;
  }
  return nil;
}

// -----------------------------------------------------------------------------
/// @brief Examines the successors of @a node (excluding @a node) in the current
/// game variation available from @a game. Returns the first node found that
/// contains a move. Returns @e nil if no move can be found.
// -----------------------------------------------------------------------------
+ (GoNode*) nodeWithNextMove:(GoNode*)node inCurrentGameVariation:(GoGame*)game
{
  GoNodeModel* nodeModel = game.nodeModel;

  int startIndexOfNode = [nodeModel indexOfNode:node] + 1;
  int numberOfNodes = nodeModel.numberOfNodes;

  for (int indexOfNode = startIndexOfNode; indexOfNode < numberOfNodes; indexOfNode++)
  {
    node = [nodeModel nodeAtIndex:indexOfNode];
    if (node.goMove)
      return node;
  }

  return nil;
}

// -----------------------------------------------------------------------------
/// @brief Examines the successors of @a node (excluding @a node) in the current
/// game variation available from @a game. Returns @e true if at least one
/// successor node contains a move. Returns @e false if no successor node
/// contains a move.
// -----------------------------------------------------------------------------
+ (bool) nodeWithNextMoveExists:(GoNode*)node inCurrentGameVariation:(GoGame*)game
{
  return [GoUtilities nodeWithNextMove:node inCurrentGameVariation:game] != nil;
}

// -----------------------------------------------------------------------------
/// @brief Examines the ancestors of @a node (excluding @a node). Returns the
/// number of ancestor nodes that contain a move. Returns zero if @a node is
/// @e nil.
// -----------------------------------------------------------------------------
+ (int) numberOfMovesBeforeNode:(GoNode*)node
{
  int numberOfMovesBeforeNode = 0;

  if (node)
    node = node.parent;
  while (node)
  {
    if (node.goMove)
      numberOfMovesBeforeNode++;
    node = node.parent;
  }

  return numberOfMovesBeforeNode;
}

// -----------------------------------------------------------------------------
/// @brief Examines the direct descendants of @a node (excluding @a node).
/// Returns the number of direct descendant nodes that contain a move. Returns
/// zero if @a node is @e nil.
// -----------------------------------------------------------------------------
+ (int) numberOfMovesAfterNode:(GoNode*)node
{
  int numberOfMovesAfterNode = 0;

  // TODO xxx Variation support
  if (node)
    node = node.firstChild;
  while (node)
  {
    if (node.goMove)
      numberOfMovesAfterNode++;
    node = node.firstChild;
  }

  return numberOfMovesAfterNode;
}

// -----------------------------------------------------------------------------
/// @brief Examines nodes starting at the beginning of the current game
/// variation available from @a game (i.e. the root node). Returns the node that
/// is closest to @a node that also contains setup information, i.e. a
/// GoNodeSetup object. Returns @a node itself if it contains setup information.
/// Returns @e nil if no setup information can be found.
// -----------------------------------------------------------------------------
+ (GoNode*) nodeWithMostRecentSetup:(GoNode*)node inCurrentGameVariation:(GoGame*)game
{
  GoNode* mostRecentNodeWithSetup = nil;

  GoNodeModel* nodeModel = game.nodeModel;
  int numberOfNodes = nodeModel.numberOfNodes;

  // For efficiency reasons we perform a forward search, starting at the root
  // node, which is also why the search is restricted to the current game
  // variation. Technically we could search backwards, starting at the supplied
  // node and examining its ancestors, but in the vast majority of cases we have
  // only a few setup nodes at the beginning of the variation, and many move
  // nodes after the setup. So in games with many moves searching backwards
  // would require hundreds of iterations, while searching forwards should
  // always finish within 10 iterations or so.
  for (int indexOfNode = 0; indexOfNode < numberOfNodes; ++indexOfNode)
  {
    GoNode* candidateNode = [nodeModel nodeAtIndex:indexOfNode];

    // Break early - no setup is possible after the first move is played. Also
    // setup and move in the same node are not possible.
    if (candidateNode.goMove)
      break;

    if (candidateNode.goNodeSetup)
      mostRecentNodeWithSetup = candidateNode;

    if (candidateNode == node)
      break;
  }

  return mostRecentNodeWithSetup;
}

// -----------------------------------------------------------------------------
/// @brief Examines @a node and its ancestors. Returns the first node found that
/// changes the board state. Returns @a node itself if it changes the board
/// state. Returns @e nil if no node can be found that changes the board state.
/// A node is considered to change the board state if it contains either setup
/// information (i.e. a GoNodeSetup object) or a move.
// -----------------------------------------------------------------------------
+ (GoNode*) nodeWithMostRecentBoardStateChange:(GoNode*)node
{
  while (node)
  {
    if (node.goMove || node.goNodeSetup)
      return node;
    node = node.parent;
  }
  return nil;
}

// -----------------------------------------------------------------------------
/// @brief Returns true if the content of @a node warrants showing an "info"
/// indicator to the user when displaying an overview of @a node.
// -----------------------------------------------------------------------------
+ (bool) showInfoIndicatorForNode:(GoNode*)node
{
  GoMove* move = node.goMove;
  if (move && move.goMoveValuation != GoMoveValuationNone)
    return true;

  GoNodeAnnotation* nodeAnnotation = node.goNodeAnnotation;
  if (! nodeAnnotation)
    return false;

  // GoNodeAnnotation must contain something else besides the hotspot
  // designation
  if (nodeAnnotation.shortDescription != nil ||
      nodeAnnotation.longDescription != nil ||
      nodeAnnotation.goBoardPositionValuation != GoBoardPositionValuationNone ||
      nodeAnnotation.estimatedScoreSummary != GoScoreSummaryNone)
  {
    return true;
  }
  else
  {
    return false;
  }
}

// -----------------------------------------------------------------------------
/// @brief Returns true if the content of @a node warrants showing a "hotspot"
/// indicator to the user when displaying an overview of @a node.
// -----------------------------------------------------------------------------
+ (bool) showHotspotIndicatorForNode:(GoNode*)node
{
  GoNodeAnnotation* nodeAnnotation = node.goNodeAnnotation;
  if (! nodeAnnotation)
    return false;
  else if (nodeAnnotation.goBoardPositionHotspotDesignation == GoBoardPositionHotspotDesignationNone)
    return false;
  else
    return true;
}

@end
