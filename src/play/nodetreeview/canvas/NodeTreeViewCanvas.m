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
#import "NodeTreeViewCanvas.h"
#import "NodeTreeViewCanvasAdditions.h"
#import "NodeTreeViewCell.h"
#import "NodeTreeViewCellPosition.h"
#import "../../model/NodeTreeViewModel.h"
#import "../../../go/GoGame.h"
#import "../../../go/GoMove.h"
#import "../../../go/GoNode.h"
#import "../../../go/GoNodeModel.h"
#import "../../../go/GoNodeSetup.h"
#import "../../../go/GoPlayer.h"
#import "../../../shared/LongRunningActionCounter.h"


@class BranchTuple;

// TODO xxx document
@interface Branch : NSObject
{
@public
  Branch* lastChildBranch;
  Branch* previousSiblingBranch;
  Branch* parentBranch;
  // The BranchTuple in the parent branch that contains the branching node from
  // which the branch is descending
  BranchTuple* parentBranchTupleBranchingNode;
  NSMutableArray* branchTuples;
  unsigned short yPosition;
}
@end

@implementation Branch
@end

// TODO xxx document
@interface BranchTuple : NSObject
{
@public
  unsigned short xPositionOfFirstCell;
  GoNode* node;
  unsigned short numberOfCellsForNode;
  // For a cell to be at the exact center numberOfCellsForNode must be an uneven number
  unsigned short indexOfCenterCell;
  enum NodeTreeViewCellSymbol symbol;
  Branch* branch;
  NSMutableArray* childBranches;
}
@end

@implementation BranchTuple
@end


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for NodeTreeViewCanvas.
// -----------------------------------------------------------------------------
@interface NodeTreeViewCanvas()
@property(nonatomic, assign) NodeTreeViewModel* nodeTreeViewModel;
@property(nonatomic, assign) bool canvasNeedsUpdate;
@property(nonatomic, retain) NSMutableDictionary* cellsDictionary;
@end


@implementation NodeTreeViewCanvas

#pragma mark - Initialization and deallocation

// -----------------------------------------------------------------------------
/// @brief Initializes a NodeTreeViewCanvas object with a canvas of size zero.
///
/// @note This is the designated initializer of NodeTreeViewCanvas.
// -----------------------------------------------------------------------------
- (id) initWithModel:(NodeTreeViewModel*)nodeTreeViewModel;
{
  // Call designated initializer of superclass (NSObject)
  self = [super init];
  if (! self)
    return nil;

  self.nodeTreeViewModel = nodeTreeViewModel;

  self.canvasNeedsUpdate = false;
  self.canvasSize = CGSizeZero;
  self.cellsDictionary = [NSMutableDictionary dictionary];

  [self setupNotificationResponders];

  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this NodeTreeViewCanvas object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  [self removeNotificationResponders];

  self.nodeTreeViewModel = nil;
  self.cellsDictionary = nil;

  [super dealloc];
}

#pragma mark - Setup/remove notification responders

// -----------------------------------------------------------------------------
/// @brief Private helper for the initializer.
// -----------------------------------------------------------------------------
- (void) setupNotificationResponders
{
  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(goGameDidCreate:) name:goGameDidCreate object:nil];
  [center addObserver:self selector:@selector(nodeTreeLayoutDidChange:) name:nodeTreeLayoutDidChange object:nil];
  [center addObserver:self selector:@selector(longRunningActionEnds:) name:longRunningActionEnds object:nil];
}

// -----------------------------------------------------------------------------
/// @brief Private helper.
// -----------------------------------------------------------------------------
- (void) removeNotificationResponders
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notification responders

// -----------------------------------------------------------------------------
/// @brief Responds to the #goGameDidCreate notification.
// -----------------------------------------------------------------------------
- (void) goGameDidCreate:(NSNotification*)notification
{
  self.canvasNeedsUpdate = true;
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #nodeTreeLayoutDidChange notification.
// -----------------------------------------------------------------------------
- (void) nodeTreeLayoutDidChange:(NSNotification*)notification
{
  self.canvasNeedsUpdate = true;
  [self delayedUpdate];
}

// -----------------------------------------------------------------------------
/// @brief Responds to the #longRunningActionEnds notification.
// -----------------------------------------------------------------------------
- (void) longRunningActionEnds:(NSNotification*)notification
{
  [self delayedUpdate];
}

#pragma mark - Updaters

// -----------------------------------------------------------------------------
/// @brief Internal helper that correctly handles delayed updates.
// -----------------------------------------------------------------------------
- (void) delayedUpdate
{
  if ([LongRunningActionCounter sharedCounter].counter > 0)
    return;

  if ([NSThread currentThread] != [NSThread mainThread])
  {
    [self performSelectorOnMainThread:@selector(delayedUpdate) withObject:nil waitUntilDone:YES];
    return;
  }

  [self updateCanvas];
}

// -----------------------------------------------------------------------------
/// @brief Updater method.
// -----------------------------------------------------------------------------
- (void) updateCanvas
{
  if (! self.canvasNeedsUpdate)
    return;
  self.canvasNeedsUpdate = false;

  [self recalc1];
}

#pragma mark - Public API

// -----------------------------------------------------------------------------
/// @brief Returns the NodeTreeViewCell object that is located at position
/// @a position on the canvas. Returns @e nil if @a position denotes a position
/// that is outside the canvas' bounds.
// -----------------------------------------------------------------------------
- (NodeTreeViewCell*) cellAtPosition:(NodeTreeViewCellPosition*)position;
{
  NodeTreeViewCell* cell = [self.cellsDictionary objectForKey:position];
  if (cell)
    return cell;

  // TODO xxx check canvas bounds and return nil if out of bounds
  return [NodeTreeViewCell emptyCell];
}

// TODO xxx document
- (NSArray*) cellsInRow:(int)row
{
  // TODO xxx implement
  return nil;
}

#pragma mark - Private API

// TODO xxx document
//typedef struct
//{
//  unsigned short xPositionOfFirstCell;
//  GoNode* node;
//  unsigned short numberOfCellsForNode;
//  enum NodeTreeViewCellSymbol symbol;
//} BranchTuple;
//
//- (NSValue*) valueWithBranchTuple:(BranchTuple)branchTuple
//{
//  return [NSValue valueWithBytes:&branchTuple objCType:@encode(BranchTuple)];
//}
//
//- (BranchTuple) branchTupleValue:(NSValue*)value
//{
//  BranchTuple branchTupleValue;
//
//  if (@available(iOS 11.0, *))
//    [value getValue:&branchTupleValue size:sizeof(BranchTuple)];
//  else
//    [value getValue:&branchTupleValue];
//
//  return branchTupleValue;
//}

// General order of algorithm:
// 1. Iterate tree. Results:
//    - Branches
//    - Depth-first ordering of branches
//    - Ordered list of NodeTreeViewCell objects in each branch, with the
//      following values
//      - NodeTreeViewCellSymbol value
//      - part/parts values => User preference "Condense tree"
//    - NodeTreeViewCellPosition with preliminary x-coordinate. This can still
//      change if user preference "Align move nodes" is enabled.
//    - Preliminary length of a branch, based on the number of NodeTreeViewCell
//      objects
// 2. Iterate branches. Results:
//    - NodeTreeViewCellPosition with final x-coordinate => User preference
//      "Align move nodes"
//    - Updated length of a branch, based on the x-coordinate of the first and
//      last NodeTreeViewCellPosition
//    - NodeTreeViewCellPosition with y-coordinate, based on final
//      x-coordinates and branch lengths
// 3. Iterate branches / NodeTreeViewCell objects. Result:
//    - NodeTreeViewCellLines value for property lines
//    - NodeTreeViewCellLines value for property linesSelectedGameVariation
// 4. Select cell
- (void) recalc1
{
  GoNodeModel* nodeModel = [GoGame sharedGame].nodeModel;

  bool condenseTree = self.nodeTreeViewModel.condenseTree;
  bool alignMoveNodes = self.nodeTreeViewModel.alignMoveNodes;
  enum NodeTreeViewBranchingStyle branchingStyle = self.nodeTreeViewModel.branchingStyle;
  int numberOfCellsOfMultipartCell = self.nodeTreeViewModel.numberOfCellsOfMultipartCell;

  // ----------
  // Part 1: Iterate tree to find out about branches and their ordering
  // ----------
  NSMutableArray* stack = [NSMutableArray array];

  GoNode* currentNode = nodeModel.rootNode;

  // TODO xxx The branches array may no longer be needed
  // Stores branches in depth-first order. Elements are arrays consisting of
  // tuples.
  NSMutableArray* branches = [NSMutableArray array];
  // TODO xxx remove if no longer needed
  // Maps child branches to their parent branches, including the place in the
  // parent branch where the branching point is.
  // Key = Index of child branch in branches array
  // Value = Tuple consisting of
  //         1) Index of parent branch in branches array
  //         2) Index of element in the parent branch that represents the parent
  //            cell in the parent branch. If the parent cell in the parent
  //            branch is a multipart cell this refers to the first part of the
  //            multipart cell.
//  NSMutableDictionary* childToParentBranchMap = [NSMutableDictionary dictionary];
  // Key = NSValue enapsulating a GoNode object. The GoNode is a branching node,
  //       i.e. a node that has multiple child nodes.
  // Value = List with child branches. The parent branch, i.e. the branch in
  //         which the branching node is located, is not in the list.
  NSMutableDictionary* branchingNodeToChildBranchesMap = [NSMutableDictionary dictionary];
  Branch* parentBranch = nil;  // if a new branch is created, this must be used as the new branch's parent branch
  unsigned short xPosition = 0;
  NSMutableArray* moveData = [NSMutableArray array];
  int highestMoveNumberThatAppearsInAtLeastTwoBranches = -1;

  while (true)
  {
    // TODO xxx this description is outdated
    // Elements are tuples consisting of a GoNode object and its associated
    // NodeTreeViewCell object. If the user preference "Condense tree" is
    // enabled then GoNode objects with certain properties will result in
    // multiple tuples with the same GoNode object but different
    // NodeTreeViewCell objects.
    Branch* branch = nil;
    NSUInteger indexOfBranch = -1;
    while (currentNode)
    {
      // TODO xxx node visit start

      // Create the array that holds the branch information only on demand, i.e.
      // when there actually *is* a node in the branch. This requires a
      // nil-check here within the while-loop for every node. A nil-check is
      // still more efficient than creating an array for every node when the
      // outer while loop pops the stack and checks for a next sibling for
      // every node.
      if (! branch)
      {
        branch = [[[Branch alloc] init] autorelease];
        branch->branchTuples = [NSMutableArray array];
        branch->lastChildBranch = nil;
        branch->previousSiblingBranch = nil;
        branch->parentBranch = parentBranch;
        branch->yPosition = 0;

        // Perform linkage of the new branch with other branches. Obviously this
        // needs to happen only if there ***is*** a parent branch => there is no
        // parent branch only if the current branch is the main branch.
        if (parentBranch)
        {
          GoNode* branchingNode = currentNode.parent;

          // TODO xxx Try to find a faster way how to determine the branching node tuple
          for (BranchTuple* parentBranchTuple in parentBranch->branchTuples)
          {
            if (parentBranchTuple->node == branchingNode)
            {
              // Remember the result of the search so that future operations
              // don't have to repeat the search
              branch->parentBranchTupleBranchingNode = parentBranchTuple;

              if (! parentBranchTuple->childBranches)
              {
                parentBranchTuple->childBranches = [NSMutableArray array];

                // Also store the child branch list in a dictionary so that it
                // can be easily looked up later on without having to search
                // through a branch's branch tuples
                // TODO xxx could also store the branch tuple of the branching node -> would this help later on?
                NSValue* key = [NSValue valueWithNonretainedObject:branchingNode];
                branchingNodeToChildBranchesMap[key] = parentBranchTuple->childBranches;
              }
              [parentBranchTuple->childBranches addObject:branch];

              break;
            }
          }

          if (parentBranch->lastChildBranch)
          {
            for (Branch* childBranch = parentBranch->lastChildBranch; childBranch; childBranch = childBranch->previousSiblingBranch)
            {
              if (! childBranch->previousSiblingBranch)
              {
                childBranch->previousSiblingBranch = branch;
                break;
              }
            }
          }
          else
          {
            parentBranch->lastChildBranch = branch;
          }
        }
        else
        {
          branch->parentBranchTupleBranchingNode = nil;
        }

        [branches addObject:branch];
        indexOfBranch = branches.count - 1;
      }

      BranchTuple* branchTuple = [[[BranchTuple alloc] init] autorelease];
      branchTuple->xPositionOfFirstCell = xPosition;
      branchTuple->node = currentNode;
      branchTuple->symbol = [self symbolForNode:currentNode];
      branchTuple->numberOfCellsForNode = [self numberOfCellsForNode:currentNode condenseTree:condenseTree numberOfCellsOfMultipartCell:numberOfCellsOfMultipartCell];
      // This assumes that numberOfCellsForNode is always an uneven number
      branchTuple->indexOfCenterCell = floorf(branchTuple->numberOfCellsForNode / 2.0);
      branchTuple->branch = branch;
      branchTuple->childBranches = nil;

      [branch->branchTuples addObject:branchTuple];

      xPosition += branchTuple->numberOfCellsForNode;

      if (alignMoveNodes)
      {
        GoMove* move = currentNode.goMove;
        if (move)
        {
          NSMutableArray* moveDataTuples;

          int moveNumber = move.moveNumber;
          if (moveNumber > moveData.count)
          {
            moveDataTuples = [NSMutableArray array];
            [moveData addObject:moveDataTuples];
          }
          else
          {
            moveDataTuples = [moveData objectAtIndex:moveNumber - 1];
          }

          [moveDataTuples addObject:@[branch, branchTuple]];

          if (moveDataTuples.count > 1)
          {
            if (moveNumber > highestMoveNumberThatAppearsInAtLeastTwoBranches)
              highestMoveNumberThatAppearsInAtLeastTwoBranches = moveNumber;
          }
        }
      }

      // TODO xxx node visit end

      [stack addObject:branchTuple];

      currentNode = currentNode.firstChild;
    }

    if (stack.count > 0)
    {
      BranchTuple* branchTuple = stack.lastObject;
      [stack removeLastObject];

      currentNode = branchTuple->node;
      xPosition = branchTuple->xPositionOfFirstCell;
      if (! currentNode.parent || currentNode.parent.firstChild == currentNode)
        parentBranch = branchTuple->branch;
      else
        parentBranch = branchTuple->branch->parentBranch;

      currentNode = currentNode.nextSibling;
    }
    else
    {
      // We're done
      break;
    }
  }

  // ----------
  // Part 2: Align move nodes
  // In case of multipart cells, nodes are aligned along the center cell
  // ----------
  if (alignMoveNodes)
  {
    // Optimization: We only have to align moves that appear in at least two
    // branches.
    for (int indexOfMove = 0; indexOfMove < highestMoveNumberThatAppearsInAtLeastTwoBranches; indexOfMove++)
    {
      NSMutableArray* moveDataTuples = [moveData objectAtIndex:indexOfMove];

      // If the move appears in only a single branch there can be no
      // mis-alignment => we can go to the next move
      // Note: We can't break off the alignment process entirely from this
      // condition. It's entirely possible that for a time there is only a
      // single branch that has moves, and that later on child branches can
      // split off again from that branch so that the count increases again to
      // 2 or more. In the following example we see that although the count is
      // 1 for M1, M3 and M6, the alignment process needs to continue each time.
      // o---M1---M2
      //     +----M2---M3---M4---M5---M6---M7
      //               +----M4---M5   +----M7
      //               +----M4
      //    c=1   c=2  c=1  c=3  c=2  c=1  c=2  [...]
      if (moveDataTuples.count == 1)
        continue;

      unsigned short highestXPositionOfCenterCell = 0;
      bool isFirstBranch = true;
      bool currentMoveIsAlignedInAllBranches = true;

      for (NSArray* moveDataTuple in moveDataTuples)
      {
        BranchTuple* branchTuple = moveDataTuple.lastObject;
        unsigned short xPositionOfCenterCell = branchTuple->xPositionOfFirstCell + branchTuple->indexOfCenterCell;
        if (isFirstBranch)
        {
          highestXPositionOfCenterCell = xPositionOfCenterCell;
          isFirstBranch = false;
        }
        else
        {
          if (xPositionOfCenterCell != highestXPositionOfCenterCell)
          {
            currentMoveIsAlignedInAllBranches = false;
            if (xPositionOfCenterCell > highestXPositionOfCenterCell)
              highestXPositionOfCenterCell = xPositionOfCenterCell;
          }
        }
      }

      if (currentMoveIsAlignedInAllBranches)
        continue;

      for (NSArray* moveDataTuple in moveDataTuples)
      {
        Branch* branch = moveDataTuple.firstObject;
        BranchTuple* branchTuple = moveDataTuple.lastObject;
        unsigned short xPositionOfCenterCell = branchTuple->xPositionOfFirstCell + branchTuple->indexOfCenterCell;

        // Branch is already aligned
        if (xPositionOfCenterCell == highestXPositionOfCenterCell)
          continue;

        NSUInteger indexOfFirstBranchTupleToShift = [branch->branchTuples indexOfObject:branchTuple];
        unsigned short alignOffset = highestXPositionOfCenterCell - xPositionOfCenterCell;

        // It is not sufficient to shift only the tuples of the current branch
        // => there may be child branches whose tuple positions also need to be
        // shifted. In the following example, when M2 of the main branch is
        // aligned, the cells of the child branches that contain M3 and M4 also
        // need to be shifted.
        // o---M1---M2---A----A
        //     |    +----M3   +----A----M4
        //     +----A----M2

        NSMutableArray* branchesToShift = [NSMutableArray array];
        [branchesToShift addObject:branch];
        bool shiftingInitialBranch = true;

        // Reusable local function
        void (^shiftBranchTuple) (BranchTuple*) = ^(BranchTuple* branchTupleToShift)
        {
          branchTupleToShift->xPositionOfFirstCell += alignOffset;

          NSValue* key = [NSValue valueWithNonretainedObject:branchTupleToShift->node];
          NSMutableArray* childBranches = [branchingNodeToChildBranchesMap objectForKey:key];
          if (childBranches)
            [branchesToShift addObjectsFromArray:childBranches];
        };

        // We start the shifting process by going through the remaining tuples
        // of the initial branch. When we find a tuple that represents a
        // branching point we add the child branches that branch off of that
        // point to the list. Subsequent iterations of the while-loop will go
        // through the child branches that were added and repeat the process of
        // shifting and looking for child branches. Eventually the branch
        // hierarchy will be exhausted and no further child branches will be
        // added to the list, at which point the while-loop will stop.
        while (branchesToShift.count > 0)
        {
          Branch* branchToShift = branchesToShift.firstObject;
          [branchesToShift removeObjectAtIndex:0];
          NSMutableArray* branchTuplesToShift = branchToShift->branchTuples;

          if (shiftingInitialBranch)
          {
            shiftingInitialBranch = false;

            // Enumeration by index is slower than fast enumeration, but we
            // can't avoid using it because we have to start at a non-zero index
            // and fast enumeration does not allow to specify a non-zero start
            // index
            NSUInteger numberOfBranchTuples = branchTuplesToShift.count;
            for (NSUInteger indexOfBranchTupleToShift = indexOfFirstBranchTupleToShift; indexOfBranchTupleToShift < numberOfBranchTuples; indexOfBranchTupleToShift++)
            {
              BranchTuple* branchTupleToShift = [branchTuplesToShift objectAtIndex:indexOfBranchTupleToShift];
              shiftBranchTuple(branchTupleToShift);
            }
          }
          else
          {
            for (BranchTuple* branchTupleToShift in branchTuplesToShift)
              shiftBranchTuple(branchTupleToShift);
          }
        }
      }
    }
  }

  // ----------
  // Part 3: Determine y-coordinates
  // ----------
//  unsigned short numberOfCellsForBranchingNode = condenseTree ? 1 : 1;  // TODO xxx correct numbers, similar to numberOfCellsForNode
  // In the worst case each branch is on its own y-position => create the array
  // to cater for this worst case
  NSUInteger numberOfBranches = branches.count;
  unsigned short lowestOccupiedXPositionOfRow[numberOfBranches];
  for (NSUInteger indexOfBranch = 0; indexOfBranch < numberOfBranches; indexOfBranch++)
    lowestOccupiedXPositionOfRow[indexOfBranch] = -1;
  unsigned short highestYPosition = 0;

  // TODO xxx should be empty
  [stack removeAllObjects];

  Branch* currentBranch = branches.firstObject;

  while (true)
  {
    while (currentBranch)
    {
      // Start visit branch
      // The y-position of a child branch is at least one below the y-position
      // of the parent branch
      unsigned short yPosition;
      if (currentBranch->parentBranch)
        yPosition = currentBranch->parentBranch->yPosition + 1;
      else
        yPosition = 0;

      BranchTuple* lastBranchTuple = currentBranch->branchTuples.lastObject;
      unsigned short highestXPositionOfBranch = (lastBranchTuple->xPositionOfFirstCell +
                                                 lastBranchTuple->numberOfCellsForNode -
                                                 1);
      while (highestXPositionOfBranch >= lowestOccupiedXPositionOfRow[yPosition])
        yPosition++;

      currentBranch->yPosition = yPosition;

      if (currentBranch->yPosition > highestYPosition)
        highestYPosition = currentBranch->yPosition;

      unsigned short lowestXPositionOfBranch;
      if (currentBranch->parentBranch)
      {
        lowestXPositionOfBranch = currentBranch->parentBranchTupleBranchingNode->xPositionOfFirstCell;

        // Diagonal branching style allows for a small optimization of the
        // available space on the LAST child branch:
        // A---B---C---D---E---F---G
        //     |   |\--H   |    \--I
        //      \--J\--K    \--L---M
        // The branch with node J fits on the same y-position as the branch with
        // node K because 1) the diagonal branching line leading from C to K
        // does not occupy the space of J, and there is also no vertical
        // branching line to another child node of C that would take the space
        // away from J. The situation is different for the branch with node L
        // and M: Because the branch contains two nodes it is too long and does
        // not fit on the same y-position as the branch with node I.
        if (branchingStyle == NodeTreeViewBranchingStyleDiagonal && currentBranch->parentBranchTupleBranchingNode->childBranches.lastObject == currentBranch)
        {
          // The desired space gain would be
          //   lowestXPositionOfBranch += currentBranch->parentBranchTupleBranchingNode->numberOfCellsForNode;
          // However since a diagonal line crosses only a single sub-cell, and
          // there are no sub-cells in y-direction, diagonal branching can only
          // ever gain space that is worth 1 sub-cell. As a result, when the
          // tree is condensed (which means that a multipart cell's number of
          // sub-cells is >1) the space gain from diagonal branching is never
          // sufficient to fit a branch on an y-position where it would not have
          // fit with bracket branching.
          // TODO xxx Consider making multipart cells also extend in y-direction
          lowestXPositionOfBranch += 1;
        }
      }
      else
      {
        lowestXPositionOfBranch = 0;
      }

      lowestOccupiedXPositionOfRow[yPosition] = lowestXPositionOfBranch;
      // End visit branch

      [stack addObject:currentBranch];

      currentBranch = currentBranch->lastChildBranch;
    }

    if (stack.count > 0)
    {
      currentBranch = stack.lastObject;
      [stack removeLastObject];

      currentBranch = currentBranch->previousSiblingBranch;
    }
    else
    {
      // We're done
      break;
    }
  }

  // ----------
  // Part 4: Determine lines
  // - Add lines to cells that so far contained only symbols
  // - Generate line-only cells to connect move nodes that are no longer
  //   adjacent because they were aligned to the move number
  // - Generate line-only cells that connect branches
  // ----------
  unsigned short highestXPosition = 0;
  NSMutableDictionary* cellsDictionary = [NSMutableDictionary dictionary];

  for (Branch* branch in branches)
  {
    unsigned short xPositionAfterPreviousBranchTuple;
    if (branch->parentBranch)
    {
      unsigned short xPositionAfterLastCellInBranchingTuple = (branch->parentBranchTupleBranchingNode->xPositionOfFirstCell +
                                                               branch->parentBranchTupleBranchingNode->numberOfCellsForNode);
      xPositionAfterPreviousBranchTuple = xPositionAfterLastCellInBranchingTuple;
    }
    else
    {
      xPositionAfterPreviousBranchTuple = 0;
    }

    BranchTuple* firstBranchTuple = branch->branchTuples.firstObject;
    BranchTuple* lastBranchTuple = branch->branchTuples.lastObject;

    for (BranchTuple* branchTuple in branch->branchTuples)
    {
      bool diagonalConnectionToBranchingLineEstablished = false;
      // Part 1: Generate cells with lines that connect the node to either its
      // predecessor node in the same branch (only if alignMoveNodes is true),
      // or to a branching line that reaches out from the cell with the
      // branching node (only if condenseTree is true)
      for (unsigned short xPositionOfCell = xPositionAfterPreviousBranchTuple; xPositionOfCell < branchTuple->xPositionOfFirstCell; xPositionOfCell++)
      {
        NodeTreeViewCell* cell = [NodeTreeViewCell emptyCell];
        if (branchingStyle == NodeTreeViewBranchingStyleDiagonal && branchTuple == firstBranchTuple && xPositionOfCell == xPositionAfterPreviousBranchTuple)
        {
          diagonalConnectionToBranchingLineEstablished = true;
          cell.lines = NodeTreeViewCellLineCenterToTopLeft | NodeTreeViewCellLineCenterToRight;  // connect to branching line
        }
        else
        {
          cell.lines = NodeTreeViewCellLineCenterToLeft | NodeTreeViewCellLineCenterToRight;
        }

        NodeTreeViewCellPosition* position = [NodeTreeViewCellPosition positionWithX:xPositionOfCell y:branch->yPosition];
        cellsDictionary[position] = cell;
      }

      // Part 2: If it's a branching node then generate cells below the
      // branching node that contain the branching lines needed to connect the
      // branching node to its child nodes. The following schematic depicts what
      // kind of lines need to be generated for each branching style when
      // condenseTree is enabled, i.e. when multipart cells are involved.
      // "N" marks the center cells of multipart cells that represent a node.
      // "o" marks branching line junctions.
      //
      // NodeTreeViewBranchingStyleDiagonal     NodeTreeViewBranchingStyleBracket
      //
      //     0    1    2    3    4    5           0    1    2    3    4    5
      //   +---++---++---+                      +---++---++---+
      //   |   ||   ||   |                      |   ||   ||   |
      // 0 |   || N ||   |                      |   || N ||   |
      //   |   || |\||   |                      |   || | ||   |
      //   +---++-|-++---+                      +---++-|-++---+
      //   +---++-|-++---++---++---++---+       +---++-|-++---++---++---++---+
      //   |   || | ||\  ||   ||   ||   |       |   || | ||   ||   ||   ||   |
      // 1 |   || o || o---------N ||   |       |   || o--------------N ||   |
      //   |   || |\||   ||   ||   ||   |       |   || | ||   ||   ||   ||   |
      //   +---++-|-++---++---++---++---+       +---++-|-++---++---++---++---+
      //   +---++-|-++---++---++---++---+       +---++-|-++---++---++---++---+
      //   |   || | ||\  ||   ||   ||   |       |   || | ||   ||   ||   ||   |
      // 2 |   || | || o---------N ||   |       |   || o--------------N ||   |
      //   |   || | ||   ||   ||   ||   |       |   || | ||   ||   ||   ||   |
      //   +---++-|-++---++---++---++---+       +---++-|-++---++---++---++---+
      //   +---++-|-++---++---++---++---+       +---++-|-++---++---++---++---+
      //   |   || | ||   ||   ||   ||   |       |   || | ||   ||   ||   ||   |
      // 3 |   || o ||   ||   ||   ||   |       |   || | ||   ||   ||   ||   |
      //   |   ||  \||   ||   ||   ||   |       |   || | ||   ||   ||   ||   |
      //   +---++---++---++---++---++---+       +---++-|-++---++---++---++---+
      //   +---++---++---++---++---++---+       +---++-|-++---++---++---++---+
      //   |   ||   ||\  ||   ||   ||   |       |   || | ||   ||   ||   ||   |
      // 4 |   ||   || o---------N ||   |       |   || o--------------N ||   |
      //   |   ||   ||   ||   ||   ||   |       |   ||   ||   ||   ||   ||   |
      //   +---++---++---++---++---++---+       +---++---++---++---++---++---+
      //
      // Cells to be generated on each y-position:
      // - y=0: 1/0, 2/0                             1/0, 2/0
      // - y=1  1/1, 2/1                             1/1, 2/1
      // - y=2  1/2                                  1/2
      // - y=3  2/3                                  1/4, 2/4

      if (branchTuple->childBranches)
      {
        Branch* lastChildBranch = branchTuple->childBranches.lastObject;

        unsigned short yPositionBelowBranchingNode = branch->yPosition + 1;
        unsigned short yPositionOfLastChildBranch = lastChildBranch->yPosition;

        NSUInteger indexOfNextChildBranchToHorizontallyConnect = 0;
        Branch* nextChildBranchToHorizontallyConnect = [branchTuple->childBranches objectAtIndex:indexOfNextChildBranchToHorizontallyConnect];
        NSUInteger indexOfNextChildBranchToDiagonallyConnect = -1;
        Branch* nextChildBranchToDiagonallyConnect = nil;
        if (branchingStyle == NodeTreeViewBranchingStyleDiagonal)
        {
          Branch* firstChildBranch = branchTuple->childBranches.firstObject;
          if (firstChildBranch->yPosition > yPositionBelowBranchingNode)
          {
            indexOfNextChildBranchToDiagonallyConnect = 0;
            nextChildBranchToDiagonallyConnect = firstChildBranch;
          }
          // If there is a second child branch it is guaranteed to have an
          // y-position that is greater than yPositionBelowBranchingNode
          else if (branchTuple->childBranches.count > 1)
          {
            indexOfNextChildBranchToDiagonallyConnect = 1;
            nextChildBranchToDiagonallyConnect = [branchTuple->childBranches objectAtIndex:1];
          }
        }

        unsigned int xPositionOfVerticalLineCell = branchTuple->xPositionOfFirstCell + branchTuple->indexOfCenterCell;

        for (unsigned short yPosition = yPositionBelowBranchingNode; yPosition <= yPositionOfLastChildBranch; yPosition++)
        {
          NodeTreeViewCellLines lines = NodeTreeViewCellLineNone;

          if (branchingStyle == NodeTreeViewBranchingStyleDiagonal)
          {
            if (yPosition < yPositionOfLastChildBranch)
            {
              lines |= NodeTreeViewCellLineCenterToTop;

              if (nextChildBranchToDiagonallyConnect && yPosition + 1 == nextChildBranchToDiagonallyConnect->yPosition)
                lines |= NodeTreeViewCellLineCenterToBottomRight;

              if (yPosition + 1 < yPositionOfLastChildBranch)
                lines |= NodeTreeViewCellLineCenterToBottom;
            }
          }
          else
          {
            lines |= NodeTreeViewCellLineCenterToTop;

            if (yPosition == nextChildBranchToHorizontallyConnect->yPosition)
              lines |= NodeTreeViewCellLineCenterToRight;

            if (yPosition < yPositionOfLastChildBranch)
              lines |= NodeTreeViewCellLineCenterToBottom;
          }

          // For diagonal branching style, no cell needs to be generated on the
          // last y-position
          if (lines != NodeTreeViewCellLineNone)
          {
            NodeTreeViewCell* cell = [NodeTreeViewCell emptyCell];
            cell.lines = lines;

            NodeTreeViewCellPosition* position = [NodeTreeViewCellPosition positionWithX:xPositionOfVerticalLineCell y:yPosition];
            cellsDictionary[position] = cell;
          }

          // If the branching node occupies more than one cell then we need to
          // create additional cells if there is a branch on the y-position
          // that needs a horizontal connection
          if (branchTuple->numberOfCellsForNode > 1 && yPosition == nextChildBranchToHorizontallyConnect->yPosition)
          {
            // TODO xxx this can be assigned outside of any loops
            NodeTreeViewCellLines linesOfFirstCell;
            if (branchingStyle == NodeTreeViewBranchingStyleDiagonal)
              linesOfFirstCell = NodeTreeViewCellLineCenterToTopLeft | NodeTreeViewCellLineCenterToRight;
            else
              linesOfFirstCell = NodeTreeViewCellLineCenterToLeft | NodeTreeViewCellLineCenterToRight;

            unsigned short xPositionOfLastCell = branchTuple->xPositionOfFirstCell + branchTuple->numberOfCellsForNode - 1;
            for (unsigned short xPosition = xPositionOfVerticalLineCell + 1; xPosition <= xPositionOfLastCell; xPosition++)
            {
              NodeTreeViewCell* cell = [NodeTreeViewCell emptyCell];
              if (xPosition == xPositionOfVerticalLineCell + 1)
                cell.lines = linesOfFirstCell;
              else
                cell.lines = NodeTreeViewCellLineCenterToLeft | NodeTreeViewCellLineCenterToRight;

              NodeTreeViewCellPosition* position = [NodeTreeViewCellPosition positionWithX:xPosition y:yPosition];
              cellsDictionary[position] = cell;
            }
          }

          if (yPosition == nextChildBranchToHorizontallyConnect->yPosition)
          {
            if (nextChildBranchToHorizontallyConnect == lastChildBranch)
            {
              // TODO xxx this does nothing, this happens on the last iteration => code analysis may not see this
              indexOfNextChildBranchToHorizontallyConnect = -1;
              nextChildBranchToHorizontallyConnect = nil;
            }
            else
            {
              indexOfNextChildBranchToHorizontallyConnect++;
              nextChildBranchToHorizontallyConnect = [branchTuple->childBranches objectAtIndex:indexOfNextChildBranchToHorizontallyConnect];
            }
          }

          if (nextChildBranchToDiagonallyConnect && yPosition + 1 == nextChildBranchToDiagonallyConnect->yPosition)
          {
            if (nextChildBranchToDiagonallyConnect == lastChildBranch)
            {
              indexOfNextChildBranchToDiagonallyConnect = -1;
              nextChildBranchToDiagonallyConnect = nil;
            }
            else
            {
              indexOfNextChildBranchToDiagonallyConnect++;
              nextChildBranchToDiagonallyConnect = [branchTuple->childBranches objectAtIndex:indexOfNextChildBranchToDiagonallyConnect];
            }
          }
        }
      }

      // Part 3: Add lines to node cells
      for (unsigned int indexOfCell = 0; indexOfCell < branchTuple->numberOfCellsForNode; indexOfCell++)
      {
        NodeTreeViewCell* cell = [NodeTreeViewCell emptyCell];
        cell.part = indexOfCell;
        cell.parts = branchTuple->numberOfCellsForNode;

        cell.symbol = branchTuple->symbol;

        // ----------------
        NodeTreeViewCellLines lines = NodeTreeViewCellLineNone;

        bool isFirstCellForNode = (indexOfCell == 0);
        bool isCellBeforeOrIncludingCenter = (indexOfCell <= branchTuple->indexOfCenterCell);
        bool isCenterCellForNode = (indexOfCell == branchTuple->indexOfCenterCell);
        bool isCellAfterOrIncludingCenter = (indexOfCell >= branchTuple->indexOfCenterCell);

        // Horizontal connecting lines to previous node in the same branch,
        // or horizontal/diagonal connecting lines to branching node in parent
        // branch
        if (isCellBeforeOrIncludingCenter)
        {
          if (branchTuple == firstBranchTuple && branch->yPosition == 0)
          {
            // Root node does not have connecting lines on the left
          }
          else
          {
            if (isFirstCellForNode)
            {
              if (branchTuple == firstBranchTuple)
              {
                // A diagonal line connecting to a branching line needs to be
                // drawn if, and only if 1) obviously branching style is
                // diagonal; 2) nodes are not represented by multipart cells
                // (for multipart cells the diagonal connecting line is located
                // in a standalone cell somewhere on the left, before the first
                // sub-cell of the multipart cell); and 3) if a diagonal
                // connecting line has not yet been established due to move
                // node alignment.
                if (branchingStyle == NodeTreeViewBranchingStyleDiagonal && branchTuple->numberOfCellsForNode == 1 && ! diagonalConnectionToBranchingLineEstablished)
                  lines |= NodeTreeViewCellLineCenterToTopLeft;
                else
                  lines |= NodeTreeViewCellLineCenterToLeft;
              }
              else
              {
                lines |= NodeTreeViewCellLineCenterToLeft;
              }
            }
            else
            {
              lines |= NodeTreeViewCellLineCenterToLeft;
            }

            if (isCenterCellForNode)
            {
              // Whether or not to draw NodeTreeViewCellLineCenterToRight is
              // determined in the block for isCellAfterOrIncludingCenter
            }
            else
            {
              lines |= NodeTreeViewCellLineCenterToRight;
            }
          }
        }

        // Horizontal connecting lines to next node in the same branch
        if (isCellAfterOrIncludingCenter)
        {
          if (branchTuple == lastBranchTuple)
          {
            // No next node in the same branch => no connecting lines
          }
          else
          {
            lines |= NodeTreeViewCellLineCenterToRight;

            if (isCenterCellForNode)
            {
              // Whether or not to draw NodeTreeViewCellLineCenterToLeft is
              // determined in the block for isCellBeforeOrIncludingCenter
            }
            else
            {
              lines |= NodeTreeViewCellLineCenterToLeft;
            }
          }
        }

        // Vertical and/or diagonal connecting lines to child branches
        if (isCenterCellForNode && branchTuple->childBranches)
        {
          if (branchingStyle == NodeTreeViewBranchingStyleDiagonal)
          {
            Branch* firstChildBranch = branchTuple->childBranches.firstObject;
            if (branchTuple->branch->yPosition + 1 == firstChildBranch->yPosition)
              lines |= NodeTreeViewCellLineCenterToBottomRight;
            else
              lines |= NodeTreeViewCellLineCenterToBottom;

            if (branchTuple->childBranches.count > 1)
              lines |= NodeTreeViewCellLineCenterToBottom;
          }
          else
          {
            lines |= NodeTreeViewCellLineCenterToBottom;
          }
        }

        cell.lines = lines;
        // ----------------

        unsigned short xPosition = branchTuple->xPositionOfFirstCell + indexOfCell;
        NodeTreeViewCellPosition* position = [NodeTreeViewCellPosition positionWithX:xPosition y:branch->yPosition];
        cellsDictionary[position] = cell;

        if (xPosition > highestXPosition)
          highestXPosition = xPosition;
      }

      // Part 4: Adjust xPositionAfterPreviousBranchTuple so that the next
      // branch tuple can connect
      xPositionAfterPreviousBranchTuple = branchTuple->xPositionOfFirstCell + branchTuple->numberOfCellsForNode;
    }
  }

  self.cellsDictionary = cellsDictionary;
  self.canvasSize = CGSizeMake(highestXPosition + 1, highestYPosition + 1);

  // TODO xxx Currently each and every change causes a full redraw => optimize
  [[NSNotificationCenter defaultCenter] postNotificationName:nodeTreeViewContentDidChange object:nil];
}

// TODO xxx document
- (unsigned short) lengthOfBranch:(NSArray*)branch
{
  BranchTuple* firstBranchTuple = branch.firstObject;
  BranchTuple* lastBranchTuple = branch.lastObject;
  return (lastBranchTuple->xPositionOfFirstCell +
          lastBranchTuple->numberOfCellsForNode -
          firstBranchTuple->xPositionOfFirstCell);
}

- (unsigned short) highestXPositionOfBranch:(NSArray*)branch
{
  BranchTuple* lastBranchTuple = branch.lastObject;
  return (lastBranchTuple->xPositionOfFirstCell +
          lastBranchTuple->numberOfCellsForNode -
          1);
}

// TODO xxx document
- (enum NodeTreeViewCellSymbol) symbolForNode:(GoNode*)node
{
  GoNodeSetup* nodeSetup = node.goNodeSetup;
  if (nodeSetup)
  {
    bool hasBlackSetupStones = nodeSetup.blackSetupStones;
    bool hasWhiteSetupStones = nodeSetup.whiteSetupStones;
    bool hasNoSetupStones = nodeSetup.noSetupStones;

    if (hasBlackSetupStones)
    {
      if (hasWhiteSetupStones)
      {
        if (hasNoSetupStones)
          return NodeTreeViewCellSymbolBlackAndWhiteAndNoSetupStones;
        else
          return NodeTreeViewCellSymbolBlackAndWhiteSetupStones;
      }
      else if (hasNoSetupStones)
        return NodeTreeViewCellSymbolBlackAndNoSetupStones;
      else
        return NodeTreeViewCellSymbolBlackSetupStones;
    }
    else if (hasWhiteSetupStones)
    {
      if (hasNoSetupStones)
        return NodeTreeViewCellSymbolWhiteAndNoSetupStones;
      else
        return NodeTreeViewCellSymbolWhiteSetupStones;
    }
    else
    {
      return NodeTreeViewCellSymbolNoSetupStones;
    }
  }
  else if (node.goMove)
  {
    if (node.goMove.player.isBlack)
      return NodeTreeViewCellSymbolBlackMove;
    else
      return NodeTreeViewCellSymbolWhiteMove;
  }
  else if (node.goNodeAnnotation)
  {
    if (node.goNodeMarkup)
      return NodeTreeViewCellSymbolAnnotationsAndMarkup;
    else
      return NodeTreeViewCellSymbolAnnotations;
  }
  else if (node.goNodeMarkup)
  {
    return NodeTreeViewCellSymbolMarkup;
  }

  return NodeTreeViewCellSymbolEmpty;
}

// TODO xxx document
// Only move nodes are condensed, and only those move nodes that do not form
// the start or end of a sequence of moves. Move nodes within a sequence of
// moves can be uncondensed if they contain something noteworthy.
- (unsigned short) numberOfCellsForNode:(GoNode*)node
                           condenseTree:(bool)condenseTree
           numberOfCellsOfMultipartCell:(int)numberOfCellsOfMultipartCell
{
  if (! condenseTree)
    return 1;

  // Root node: Because the root node starts the main variation it is considered
  // a branching node
  if (node.isRoot)
    return numberOfCellsOfMultipartCell;

  // Branching nodes are uncondensed
  // TODO xxx new property isBranchingNode
  GoNode* firstChild = node.firstChild;
  if (firstChild != node.lastChild)
    return numberOfCellsOfMultipartCell;

  // Child nodes of a branching node
  GoNode* parent = node.parent;
  if (parent.firstChild != parent.lastChild)
    return numberOfCellsOfMultipartCell;

  // Leaf nodes
  // TODO xxx new property isLeafNode
  if (! firstChild)
    return numberOfCellsOfMultipartCell;

  // Nodes with a move => we don't care if they also contain annotations or
  // markup
  // TODO xxx is it correct to not care? e.g. a hotspot should surely be uncodensed? what about annotations/markup in general?
  if (node.goMove)
  {
    // At this point we know the node is neither the root node (i.e. it has a
    // parent) nor a leaf node (i.e. it has a first child), so it is safe to
    // examine the parent and first child content.
    // => Condense the node only if it is sandwiched between two other move
    //    nodes. If either parent or first child don't contain a move then they
    //    will be uncondensed. The move node in this case must also be
    //    uncondensed to indicate the begin or end of a sequence of moves.
    if (parent.goMove && firstChild.goMove)
      return 1;
    else
      return numberOfCellsOfMultipartCell;
  }
  // Nodes without a move (including completely empty nodes)
  else
  {
    return numberOfCellsOfMultipartCell;
  }
}

@end

#pragma mark - Implementation of NodeTreeViewCanvasAdditions

@implementation NodeTreeViewCanvas(NodeTreeViewCanvasAdditions)

#pragma mark - NodeTreeViewCanvasAdditions - Unit testing

- (NSDictionary*) getCellsDictionary
{
  return [[_cellsDictionary retain] autorelease];
}

@end
