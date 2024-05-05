// -----------------------------------------------------------------------------
// Copyright 2022-2024 Patrick Näf (herzbube@herzbube.ch)
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
@class BoardView;
@class BoardViewMetrics;
@class GoPoint;
@class MarkupModel;
@class UiSettingsModel;

NS_ASSUME_NONNULL_BEGIN

// -----------------------------------------------------------------------------
/// @brief The PanGestureHandler class is a base class that provides the
/// interface for handling different kinds of pan gestures. Subclasses implement
/// the actual handling. PanGestureHandler provides a convenience constructor
/// that creates the appropriate handler instance.
// -----------------------------------------------------------------------------
@interface PanGestureHandler : NSObject
{
}

+ (nullable PanGestureHandler*) panGestureHandlerWithUiAreaPlayMode:(enum UIAreaPlayMode)uiAreaPlayMode
                                                         markupTool:(enum MarkupTool)markupTool
                                                        markupModel:(MarkupModel*)markupModel
                                                          boardView:(BoardView*)boardView
                                                   boardViewMetrics:(BoardViewMetrics*)boardViewMetrics;

- (BOOL) gestureRecognizerShouldBegin:(UIGestureRecognizer*)gestureRecognizer
                    gestureStartPoint:(GoPoint*)gestureStartPoint;
- (void) handleGestureWithGestureRecognizerState:(UIGestureRecognizerState)recognizerState
                               gestureStartPoint:(GoPoint*)gestureStartPoint
                             gestureCurrentPoint:(nullable GoPoint*)gestureCurrentPoint;

- (NSString*) shortDescription;

@end

NS_ASSUME_NONNULL_END
