// -----------------------------------------------------------------------------
// Copyright 2015-2024 Patrick Näf (herzbube@herzbube.ch)
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
/// @brief The ExceptionUtility class is a container for various utility
/// functions related to throwing/handling exceptions.
///
/// All functions in ExceptionUtility are class methods, so there is no need to
/// create an instance of ExceptionUtility.
// -----------------------------------------------------------------------------
@interface ExceptionUtility : NSObject
{
}

+ (void) throwInvalidUIType:(enum UIType)uiType;
+ (void) throwInvalidArgumentExceptionWithFormat:(NSString*)format
                                   argumentValue:(int)argumentValue;
+ (void) throwInvalidArgumentExceptionWithErrorMessage:(NSString*)errorMessage;
+ (void) throwInternalInconsistencyExceptionWithFormat:(NSString*)format
                                         argumentValue:(int)argumentValue;
+ (void) throwInternalInconsistencyExceptionWithErrorMessage:(NSString*)errorMessage;
+ (void) throwAbstractMethodException;
+ (void) throwNotImplementedException;

@end
