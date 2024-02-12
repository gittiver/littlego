// -----------------------------------------------------------------------------
// Copyright 2011 Patrick Näf (herzbube@herzbube.ch)
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
/// @brief The Command protocol defines the interface of a command in the
/// well-known Command design pattern.
// -----------------------------------------------------------------------------
@protocol Command <NSObject>
@required
/// @brief Executes the command. Returns true if execution was successful.
- (bool) doIt;

@optional
/// @brief Undo of the actions performed by doIt(). Returns true if the undo
/// operation was successful.
- (bool) undo;

@required
/// @brief The name used by the command to identify itself.
///
/// This is a technical name that should not be displayed in the GUI. It might
/// be used, for instance, for logging purposes.
@property(nonatomic, retain) NSString* name;

@required
/// @brief True if the command's undo() method may be invoked. The default is
/// false.
@property(nonatomic, assign, getter=isUndoable) bool undoable;

@required
/// @brief Callback to be invoked after the command's doIt() has returned. The
/// callback parameters are the command instance and the value returned by
/// doIt(). doIt() and the callback are invoked in the same thread.
///
/// Callbacks can be useful if the command submitter is not the same as the
/// actor that needs the callback, or if a command is executed asynchronously
/// (see AsynchronousCommand).
///
/// Instead of a callback a command could also post a completion notification.
///
/// Why copy and not retain? Because blocks are allocated on the stack, so they
/// need to be copied to survive an unwind of the stack. If a command is
/// executed asynchronously a stack unwind is exactly what happens. Also see
/// https://www.cocoawithlove.com/2009/10/how-blocks-are-implemented-and.html
@property (copy, nonatomic) void (^completionHandler) (NSObject<Command>* command, bool success);

@end

