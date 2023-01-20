// -----------------------------------------------------------------------------
// Copyright 2012-2022 Patrick Näf (herzbube@herzbube.ch)
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
#import "BaseTestCase.h"


// -----------------------------------------------------------------------------
/// @brief The GoNodeModelTest class contains unit tests that exercise the
/// GoNodeModel class.
// -----------------------------------------------------------------------------
@interface GoNodeModelTest : BaseTestCase
{
}

- (void) testInitialState;
- (void) testChangeToMainVariation;
- (void) testChangeToVariationContainingNode;
- (void) testAncestorOfNodeInCurrentVariation;
- (void) testNodeAtIndex;
- (void) testIndexOfNode;
- (void) testAppendNode;
- (void) testDiscardNodesFromIndex;
- (void) testDiscardLeafNode;
- (void) testDiscardAllNodes;
- (void) testDiscardNodesFromIndex_FirstDiscardedNodeHasNextSibling;
- (void) testDiscardLeafNode_FirstDiscardedNodeHasNextSibling;
- (void) testDiscardAllNodes_FirstDiscardedNodeHasNextSibling;
- (void) testDiscardNodesFromIndex_FirstDiscardedNodeHasPreviousSibling;
- (void) testDiscardLeafNode_FirstDiscardedNodeHasPreviousSibling;
- (void) testDiscardAllNodes_FirstDiscardedNodeHasPreviousSibling;
- (void) testNumberOfNodes;
- (void) testNumberOfMoves;
- (void) testRootNode;
- (void) testLeafNode;

@end
