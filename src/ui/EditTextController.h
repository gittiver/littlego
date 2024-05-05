// -----------------------------------------------------------------------------
// Copyright 2011-2024 Patrick Näf (herzbube@herzbube.ch)
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
@class EditTextController;


// -----------------------------------------------------------------------------
/// @brief Enumerates different styles how EditTextController presents the
/// text for editing.
// -----------------------------------------------------------------------------
enum EditTextControllerStyle
{
  EditTextControllerStyleTextField,  ///< @brief The text is presented in a UITextField. Suitable for short, one-line texts
  EditTextControllerStyleTextView    ///< @brief The text is presented in a UITextView. Suitable for long, multi-line texts.
};


// -----------------------------------------------------------------------------
/// @brief The EditTextDelegate protocol must be implemented by the delegate
/// of EditTextController.
// -----------------------------------------------------------------------------
@protocol EditTextDelegate <NSObject>
/// @brief Asks the delegate if editing should end using @a text as the result.
/// This method is invoked when the user taps the "done" button.
///
/// The delegate should return true if @a text is valid, false if not.
/// If the delegate returns false and does not implement the delegate method
/// controller:isTextValid:validationErrorMessage:(), it should display an alert
/// prior to returning that informs the user why the text cannot be accepted. If
/// no such alert is displayed, the user will have no feedback why tapping the
/// "done" button has no effect.
- (bool) controller:(EditTextController*)editTextController shouldEndEditingWithText:(NSString*)text;
/// @brief Notifies the delegate that the editing session has ended. This method
/// is invoked when the user taps either the "done" or the "cancel" button (in
/// the former case, this method is invoked only if the delegate returns true
/// for controller:shouldEndEditingWithText:()).
///
/// @a didCancel is true if the user has cancelled editing. @a didCancel is
/// false if the user has confirmed editing.
///
/// The delegate should dismiss the EditTextController in response to this
/// method invocation.
- (void) didEndEditing:(EditTextController*)editTextController didCancel:(bool)didCancel;

@optional
/// @brief Asks the delegate if @a text is a valid text. This method is invoked
/// whenever the user makes a change to the text field or text view input
/// control.
///
/// The delegate should return true if @a text is valid, false if not.
///
/// If the delegate returns false it can optionally populate
/// @a validationErrorMessage with a validation error message text that
/// @a controller will then display to the user below the text field or text
/// view input control.
- (bool) controller:(EditTextController*)editTextController isTextValid:(NSString*)text validationErrorMessage:(NSString**)validationErrorMessage;
@end


// -----------------------------------------------------------------------------
/// @brief The EditTextController class is responsible for displaying an
/// "Edit Text" view that allows the user to edit a text string.
///
/// The "Edit Text" view consists of the following input elements:
/// - Either a UITextField or a UITextView that allows the user to enter a text
///   (initializing the EditTextController instance with an
///   #EditTextControllerStyle specifies which input element should be used)
/// - A "cancel" button used to end editing without changes. This button is
///   placed in the navigation item of EditTextController.
/// - A "done" button used to end editing, using the currently entered text as
///   the result. This button is placed in the navigation item of
///   EditTextController.
///
/// EditTextController expects to be displayed modally by a navigation
/// controller. For this reason it populates its own navigation item with
/// controls that are then expected to be displayed in the navigation bar of
/// the parent navigation controller.
///
/// EditTextController expects to be configured with a delegate that can be
/// informed when the user has finished editing the text. For this to work, the
/// delegate must implement the protocol EditTextDelegate. The delegate is also
/// notified when the user intends to end the editing session by tapping the
/// "done" button. The delegate can refuse the entered text and prevent the
/// editing session from ending (it should also display an alert to provide
/// feedback to the user why tapping the "done" button has no effect). An
/// optional delegate method allows to validate the text string whenever the
/// user performs edits, and in case of error to display a validation error
/// message.
// -----------------------------------------------------------------------------
@interface EditTextController : UIViewController <UITextFieldDelegate, UITextViewDelegate>
{
}

+ (EditTextController*) controllerWithText:(NSString*)text style:(enum EditTextControllerStyle)style delegate:(id<EditTextDelegate>)delegate;

/// @brief A context object that can be set by the client to identify the
/// context or purpose that an instance of EditTextController was created for.
@property(nonatomic, retain) id context;
/// @brief The style that EditTextController adopts for presenting the editable
/// text.
@property(nonatomic, assign) enum EditTextControllerStyle editTextControllerStyle;
/// @brief The keyboard type that EditTextController uses for editing text.
@property(nonatomic, assign) UIKeyboardType keyboardType;
/// @brief This is the delegate that will be informed when the user has
/// finished editing the text.
@property(nonatomic, assign) id<EditTextDelegate> delegate;
/// @brief When editing begins, this contains the default text (may be @e nil if
/// EditTextController was initialized with @e nil). When editing finishes with
/// the user tapping "done", this contains the text entered by the user (is
/// never @e nil, even if user entered an empty text).
@property(nonatomic, retain) NSString* text;
/// @brief Placeholder string that should be displayed instead of an empty
/// text.
@property(nonatomic, retain) NSString* placeholder;
/// @brief True if EditTextController should accept an empty text as valid
/// input.
///
/// If this property is false and the user clears the entire text, the user
/// @e must cancel editing to leave the view.
@property(nonatomic, assign) bool acceptEmptyText;
/// @brief True if the user has actually made changes to the text. False if the
/// user has cancelled editing, or if there were no changes.
///
/// This property is set after the user has finished editing the text. It is
/// useful if the delegate needs to take special action if the user made actual
/// changes.
@property(nonatomic, assign) bool textHasChanged;

@end
