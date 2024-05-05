// -----------------------------------------------------------------------------
// Copyright 2013-2024 Patrick Näf (herzbube@herzbube.ch)
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
/// @brief The DoubleTapGestureController class is a generic controller class
/// that is responsible for managing a double-tap gesture in a UIScrollView.
/// Double-tapping is used to zoom in the scroll view.
///
/// Every double-tap performs a 50% zoom-in at the location where the tap
/// occurred. Repeated double-taps zoom in up to the maximum zoom scale. Once
/// the maximum zoom scale has been reached, additional double-taps have no
/// effect.
// -----------------------------------------------------------------------------
@interface DoubleTapGestureController : NSObject <UIGestureRecognizerDelegate>
{
}

@property(nonatomic, assign) UIScrollView* scrollView;
/// @brief True if a tapping gesture is currently allowed, false if not.
@property(nonatomic, assign, getter=isTappingEnabled) bool tappingEnabled;

@end
