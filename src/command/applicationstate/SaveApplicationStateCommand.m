// -----------------------------------------------------------------------------
// Copyright 2013 Patrick Näf (herzbube@herzbube.ch)
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
#import "SaveApplicationStateCommand.h"
#import "../../go/GoGame.h"
#import "../../utility/PathUtilities.h"


@implementation SaveApplicationStateCommand

// -----------------------------------------------------------------------------
/// @brief Executes this command. See the class documentation for details.
// -----------------------------------------------------------------------------
- (bool) doIt
{
  NSKeyedArchiver* archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];

  GoGame* game = [GoGame sharedGame];
  [archiver encodeObject:game forKey:nsCodingGoGameKey];
  [archiver finishEncoding];

  NSData* encodedData = archiver.encodedData;
  NSString* archivePath = [[PathUtilities backupFolderPath] stringByAppendingPathComponent:archiveBackupFileName];
  BOOL success = [encodedData writeToFile:archivePath atomically:YES];
  [archiver release];

  if (! success)
  {
    NSString* errorMessage = [NSString stringWithFormat:@"Failed to save NSCoding archive file %@", archivePath];
    DDLogError(@"%@: %@", [self shortDescription], errorMessage);
    NSException* exception = [NSException exceptionWithName:NSGenericException
                                                     reason:errorMessage
                                                   userInfo:nil];
    @throw exception;
  }

  return true;
}

@end
