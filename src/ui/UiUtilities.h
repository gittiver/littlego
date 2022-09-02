// -----------------------------------------------------------------------------
// Copyright 2011-2021 Patrick Näf (herzbube@herzbube.ch)
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
#include "TableViewCellFactory.h"


// -----------------------------------------------------------------------------
/// @brief The UiUtilities class is a container for various utility functions
/// related to UI controls and drawing.
///
/// All functions in UiUtilities are class methods, so there is no need to
/// create an instance of UiUtilities.
// -----------------------------------------------------------------------------
@interface UiUtilities : NSObject
{
}

+ (CGFloat) radians:(CGFloat)degrees;
+ (UITableView*) createTableViewWithStyle:(UITableViewStyle)tableViewStyle withDelegateAndDataSource:(id)anObject;
+ (void) addGroupTableViewBackgroundToView:(UIView*)view;
+ (void) setupDefaultTypeCell:(UITableViewCell*)cell withText:(NSString*)text placeHolder:(NSString*)placeholder textIsRequired:(bool)textIsRequired;
+ (UIImageView*) redButtonTableViewCellBackground:(bool)selected;
+ (void) drawLinearGradientWithContext:(CGContextRef)context rect:(CGRect)rect startColor:(CGColorRef)startColor endColor:(CGColorRef)endColor;
+ (UIImage*) captureView:(UIView*)view;
+ (UIImage*) captureFrame:(CGRect)frame inView:(UIView*)view;
+ (void) drawRectWithContext:(CGContextRef)context rect:(CGRect)rect fill:(bool)fill color:(UIColor*)color;
+ (void) drawCircleWithContext:(CGContextRef)context center:(CGPoint)center radius:(CGFloat)radius fill:(bool)fill color:(UIColor*)color;
+ (UIImage*) circularTableCellViewIndicatorWithColor:(UIColor*)color;
+ (bool) isLightUserInterfaceStyle:(UITraitCollection*)traitCollection;
+ (void) applyTransparentStyleToView:(UIView*)view traitCollection:(UITraitCollection*)traitCollection5;

@end
