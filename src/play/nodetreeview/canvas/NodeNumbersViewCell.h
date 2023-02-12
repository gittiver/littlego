// -----------------------------------------------------------------------------
// Copyright 2023 Patrick Näf (herzbube@herzbube.ch)
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
/// @brief The NodeNumbersViewCell class represents a cell on the abstract node
/// numbers view canvas. NodeNumbersViewCell contains data that describes the
/// content that should be drawn when the cell is rendered on screen. A
/// NodeNumbersViewCell and its position on the node numbers view canvas is
/// uniquely identified by a NodeTreeViewCellPosition value.
// -----------------------------------------------------------------------------
@interface NodeNumbersViewCell : NSObject
{
}

+ (NodeNumbersViewCell*) emptyCell;

- (BOOL) isEqualToCell:(NodeNumbersViewCell*)otherCell;

/// @brief The 0-based number to display in the cell. The user preference
/// "numbering style" determines the meaning of the node number. This property
/// has the value -1 if the cell is empty, i.e. if it does not hold a node
/// number.
@property(nonatomic, assign) int nodeNumber;

/// @brief @e true if the node number refers to the currently selected node.
/// @e false if the node number does not refer to the currently selected node.
@property(nonatomic, assign, getter=isSelected) bool selected;

/// @brief @e true if the node number refers to a condensed move node, @e false
/// if the node number refers to an uncondensed node.
///
/// If @e true this property indicates to the node numbers drawing code that
/// there is less horizontal space  available for rendering the node number.
@property(nonatomic, assign, getter=isCondensedMoveNode) bool condensedMoveNode;

@end
