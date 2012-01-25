//
// Copyright 2011-2012 Kosher Penguin LLC 
// Created by Adar Porat (https://github.com/aporat) on 1/16/2012.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//		http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "KKPasscodeViewController.h"
#import "KKKeychain.h"
#import "KKPasscodeSettingsViewController.h"
#import "KKPasscodeLock.h"

#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>

@interface KKPasscodeViewController(Private)

- (UITextField*)passcodeTextField;
- (NSArray*)boxes;
- (UIView*)passwordHeaderViewForTextField:(UITextField*)textField;
- (void)moveToNextTableView;
- (void)moveToPreviousTableView;
- (void)incrementFailedAttemptsLabel;

@end


@implementation KKPasscodeViewController

@synthesize delegate = _delegate;
@synthesize mode;

#pragma mark -
#pragma mark UIViewController

- (void)loadView
{
	[super loadView];
	
	self.view.backgroundColor = [UIColor whiteColor];
	
	_enterPasscodeTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
	_enterPasscodeTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_enterPasscodeTableView.delegate = self;
	_enterPasscodeTableView.dataSource = self;
	_enterPasscodeTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	_enterPasscodeTableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
	[self.view addSubview:_enterPasscodeTableView];
	
	_setPasscodeTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
	_setPasscodeTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_setPasscodeTableView.delegate = self;
	_setPasscodeTableView.dataSource = self;
	_setPasscodeTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	_setPasscodeTableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
	[self.view addSubview:_setPasscodeTableView];
	
	_confirmPasscodeTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
	_confirmPasscodeTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_confirmPasscodeTableView.delegate = self;
	_confirmPasscodeTableView.dataSource = self;
	_confirmPasscodeTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	_confirmPasscodeTableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
	[self.view addSubview:_confirmPasscodeTableView];
	
	[self.view addGestureRecognizer:[[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)] autorelease]];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) || (toInterfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];

  _passcodeLockOn = [[KKKeychain getStringForKey:@"passcode_on"] isEqualToString:@"YES"];
	_eraseData = [[KKPasscodeLock sharedLock] eraseOption] && [[KKKeychain getStringForKey:@"erase_data_on"] isEqualToString:@"YES"];

	_enterPasscodeTextField = [self passcodeTextField];
	_setPasscodeTextField = [self passcodeTextField];
	_confirmPasscodeTextField = [self passcodeTextField];
	
	_tableViews = [[NSMutableArray alloc] init];
	_textFields = [[NSMutableArray alloc] init];
	_boxes = [[NSMutableArray alloc] init];
	
	if (mode == KKPasscodeModeSet || mode == KKPasscodeModeChange) {
		if (_passcodeLockOn) {
			_enterPasscodeTableView.tableHeaderView = [self passwordHeaderViewForTextField:_enterPasscodeTextField];
			[_tableViews addObject:_enterPasscodeTableView];
			[_textFields addObject:_enterPasscodeTextField];
			[_boxes addObject:[self boxes]];
			UIView *boxesView = [[[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * 0.5 - 71.0 * kPasscodeBoxesCount * 0.5, 0, 71.0 * kPasscodeBoxesCount, kPasscodeBoxHeight)] autorelease];
			boxesView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
			for (int i = 0; i < [[_boxes lastObject] count]; i++) {
				[boxesView addSubview:[[_boxes lastObject] objectAtIndex:i]];
			}
			[_enterPasscodeTableView.tableHeaderView addSubview:boxesView];
		}
		
		_setPasscodeTableView.tableHeaderView = [self passwordHeaderViewForTextField:_setPasscodeTextField];
		[_tableViews addObject:_setPasscodeTableView];
		[_textFields addObject:_setPasscodeTextField];
		[_boxes addObject:[self boxes]];
		UIView *boxesView = [[[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * 0.5 - 71.0 * kPasscodeBoxesCount * 0.5, 0, 71.0 * kPasscodeBoxesCount, kPasscodeBoxHeight)] autorelease];
		boxesView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		for (int i = 0; i < [[_boxes lastObject] count]; i++) {
			[boxesView addSubview:[[_boxes lastObject] objectAtIndex:i]];
		}
		[_setPasscodeTableView.tableHeaderView addSubview:boxesView];
		
		_confirmPasscodeTableView.tableHeaderView = [self passwordHeaderViewForTextField:_confirmPasscodeTextField];
		[_tableViews addObject:_confirmPasscodeTableView];
		[_textFields addObject:_confirmPasscodeTextField];
		[_boxes addObject:[self boxes]];
		UIView *boxesConfirmView = [[[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * 0.5 - 71.0 * kPasscodeBoxesCount * 0.5, 0, 71.0 * kPasscodeBoxesCount, kPasscodeBoxHeight)] autorelease];
		boxesConfirmView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		for (int i = 0; i < [[_boxes lastObject] count]; i++) {
			[boxesConfirmView addSubview:[[_boxes lastObject] objectAtIndex:i]];
		}
		[_confirmPasscodeTableView.tableHeaderView addSubview:boxesConfirmView];
	} else {
		_enterPasscodeTableView.tableHeaderView = [self passwordHeaderViewForTextField:_enterPasscodeTextField];
		[_tableViews addObject:_enterPasscodeTableView];
		[_textFields addObject:_enterPasscodeTextField];
		[_boxes addObject:[self boxes]];
		UIView *boxesView = [[[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * 0.5 - 71.0 * kPasscodeBoxesCount * 0.5, 0, 71.0 * kPasscodeBoxesCount, kPasscodeBoxHeight)] autorelease];
		boxesView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		for (int i = 0; i < [[_boxes lastObject] count]; i++) {
			[boxesView addSubview:[[_boxes lastObject] objectAtIndex:i]];
		}
		[_enterPasscodeTableView.tableHeaderView addSubview:boxesView];
	}
	
	[self.view addSubview:[_tableViews objectAtIndex:0]];
	
	for (int i = 1; i < [_tableViews count]; i++) {
		UITableView *tableView = [_tableViews objectAtIndex:i];
		tableView.frame = CGRectMake(tableView.frame.origin.x + self.view.bounds.size.width, tableView.frame.origin.y, tableView.frame.size.width, tableView.frame.size.height);
		[self.view addSubview:tableView];
	}
	
	[[_textFields objectAtIndex:0] becomeFirstResponder];
	[[_tableViews objectAtIndex:0] reloadData];
	[[_textFields objectAtIndex:[_tableViews count] - 1] setReturnKeyType:UIReturnKeyDone];
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		if ([_tableViews count] > 1) {
			[self moveToNextTableView];
			[self moveToPreviousTableView];
		} else {
			UITableView *tableView = [_tableViews objectAtIndex:0];
			tableView.frame = CGRectMake(tableView.frame.origin.x,
                                   tableView.frame.origin.y,
                                   self.view.bounds.size.width,
                                   self.view.bounds.size.height);
		}
	}
}

- (void)viewTapped:(UITapGestureRecognizer*)recognizer
{
	[[_textFields objectAtIndex:_tableIndex] becomeFirstResponder];
}

#pragma mark -
#pragma mark Private methods

- (UITextField*)passcodeTextField
{
	UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(29.0, 18.0, 271.0, 24.0)];
	textField.font = [UIFont systemFontOfSize:14];
	textField.text = @"";
	textField.textColor = [UIColor blackColor];
	textField.secureTextEntry = YES;
	textField.delegate = self;
	textField.keyboardAppearance = UIKeyboardAppearanceAlert;
	return textField;
}

- (void)cancelButtonPressed:(id)sender
{
	[self dismissModalViewControllerAnimated:YES];
}

- (void)incrementFailedAttemptsLabel
{
  AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

	_enterPasscodeTextField.text = @"";
	for (int i = 0; i < kPasscodeBoxesCount; i++) {
		[[[_boxes objectAtIndex:_tableIndex] objectAtIndex:i] setImage:[UIImage imageNamed:@"KKPasscodeLock.bundle/box_empty.png"]];
	}		 
	
	_failedAttemptsCount += 1;
	if (_failedAttemptsCount == 1) {
		_failedAttemptsLabel.text = @"1 Failed Passcode Attempt";
	} else {
		_failedAttemptsLabel.text = [NSString stringWithFormat:@"%i Failed Passcode Attempts", _failedAttemptsCount];
	}
	CGSize size = [_failedAttemptsLabel.text sizeWithFont:[UIFont boldSystemFontOfSize:14.0]];
	_failedAttemptsView.frame = CGRectMake((self.view.bounds.size.width - (size.width + 36.0)) / 2, 147.5, size.width + 36.0, size.height + 10.0);
	_failedAttemptsLabel.frame = CGRectMake((self.view.bounds.size.width - (size.width + 36.0)) / 2, 147.5, size.width + 36.0, size.height + 10.0); 
	
	CAGradientLayer *gradient = [CAGradientLayer layer];
	gradient.frame = _failedAttemptsView.bounds;				
	gradient.colors = [NSArray arrayWithObjects:(id)[[UIColor colorWithRed:0.714 green:0.043 blue:0.043 alpha:1.0] CGColor], 
										 (id)[[UIColor colorWithRed:0.761 green:0.192 blue:0.192 alpha:1.0] CGColor], nil];
	[_failedAttemptsView.layer insertSublayer:gradient atIndex:0];
	_failedAttemptsView.layer.masksToBounds = YES;
	
	_failedAttemptsLabel.hidden = NO;
	_failedAttemptsView.hidden = NO;
	
	if (_failedAttemptsCount == [[KKPasscodeLock sharedLock] attemptsAllowed]) {
		
		_enterPasscodeTextField.delegate = nil;
		
		if (_eraseData) {
			if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
				[UIView beginAnimations:@"fadeIn" context:nil];
				[UIView setAnimationDelay:0.25];
				[UIView setAnimationDuration:0.5];
				
				[UIView commitAnimations];
			}
						
			if ([_delegate respondsToSelector:@selector(shouldEraseApplicationData:)]) {
				[_delegate shouldEraseApplicationData:self];
			}
		} else {
			if ([_delegate respondsToSelector:@selector(didPasscodeEnteredIncorrectly:)]) {
				[_delegate didPasscodeEnteredIncorrectly:self];
			}
		}
	}
	
}

- (void)moveToNextTableView
{
	_tableIndex += 1;
	UITableView *oldTableView = [_tableViews objectAtIndex:_tableIndex - 1];
	UITableView *newTableView = [_tableViews objectAtIndex:_tableIndex];
	newTableView.frame = CGRectMake(oldTableView.frame.origin.x + self.view.bounds.size.width, oldTableView.frame.origin.y, oldTableView.frame.size.width, oldTableView.frame.size.height);
	
	for (int i = 0; i < kPasscodeBoxesCount; i++) {
		[[[_boxes objectAtIndex:_tableIndex] objectAtIndex:i] setImage:[UIImage imageNamed:@"KKPasscodeLock.bundle/box_empty.png"]];
	}
	
	[UIView beginAnimations:@"" context:nil];
	[UIView setAnimationDuration:0.25];										 
	oldTableView.frame = CGRectMake(oldTableView.frame.origin.x - self.view.bounds.size.width, oldTableView.frame.origin.y, oldTableView.frame.size.width, oldTableView.frame.size.height);
	newTableView.frame = self.view.frame;
	[UIView commitAnimations];
	
	
	[[_textFields objectAtIndex:_tableIndex - 1] resignFirstResponder];
	[[_textFields objectAtIndex:_tableIndex] becomeFirstResponder];
}

- (void)moveToPreviousTableView
{
	_tableIndex -= 1;
	UITableView *oldTableView = [_tableViews objectAtIndex:_tableIndex + 1];
	UITableView *newTableView = [_tableViews objectAtIndex:_tableIndex];
	newTableView.frame = CGRectMake(oldTableView.frame.origin.x - self.view.bounds.size.width, oldTableView.frame.origin.y, oldTableView.frame.size.width, oldTableView.frame.size.height);
	
	for (int i = 0; i < kPasscodeBoxesCount; i++) {
		[[[_boxes objectAtIndex:_tableIndex] objectAtIndex:i] setImage:[UIImage imageNamed:@"KKPasscodeLock.bundle/box_empty.png"]];
	}
	
	[UIView beginAnimations:@"" context:nil];
	[UIView setAnimationDuration:0.25];										 
	oldTableView.frame = CGRectMake(oldTableView.frame.origin.x + self.view.bounds.size.width, oldTableView.frame.origin.y, oldTableView.frame.size.width, oldTableView.frame.size.height);
	newTableView.frame = self.view.frame;
	[UIView commitAnimations];
	
	[[_textFields objectAtIndex:_tableIndex + 1] resignFirstResponder];
	[[_textFields objectAtIndex:_tableIndex] becomeFirstResponder];
}

- (void)nextDigitPressed
{
	UITextField *textField = [_textFields objectAtIndex:_tableIndex];
	
	if (![textField.text isEqualToString:@""]) {
		
		if (mode == KKPasscodeModeSet) {
			if ([textField isEqual:_setPasscodeTextField]) {
				[self moveToNextTableView];
			} else if ([textField isEqual:_confirmPasscodeTextField]) {
				if (![_confirmPasscodeTextField.text isEqualToString:_setPasscodeTextField.text]) {
					_confirmPasscodeTextField.text = @"";
					_setPasscodeTextField.text = @"";
					_passcodeConfirmationWarningLabel.text = @"Passcodes did not match. Try again.";
					[self moveToPreviousTableView];
				} else {
					if ([KKKeychain setString:_setPasscodeTextField.text forKey:@"passcode"]) {
						[KKKeychain setString:@"YES" forKey:@"passcode_on"];
					}
					
					if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
						[_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
					}
					
					[self dismissModalViewControllerAnimated:YES];
				}
			}						 
		} else if (mode == KKPasscodeModeChange) {
			NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
			if ([textField isEqual:_enterPasscodeTextField]) {
				if ([passcode isEqualToString:_enterPasscodeTextField.text]) {
					[self moveToNextTableView];
				} else {
					[self incrementFailedAttemptsLabel];
				}
			} else if ([textField isEqual:_setPasscodeTextField]) {
				if ([passcode isEqualToString:_setPasscodeTextField.text]) {
					_setPasscodeTextField.text = @"";
					_passcodeConfirmationWarningLabel.text = @"Enter a different passcode. You cannot re-use the same passcode.";
					_passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 131.5, self.view.bounds.size.width, 60.0);
				} else {
					_passcodeConfirmationWarningLabel.text = @"";
					_passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 146.5, self.view.bounds.size.width, 30.0);
					[self moveToNextTableView];
				}
			} else if ([textField isEqual:_confirmPasscodeTextField]) {
				if (![_confirmPasscodeTextField.text isEqualToString:_setPasscodeTextField.text]) {
					_confirmPasscodeTextField.text = @"";
					_setPasscodeTextField.text = @"";
					_passcodeConfirmationWarningLabel.text = @"Passcodes did not match. Try again.";
					[self moveToPreviousTableView];
				} else {
					if ([KKKeychain setString:_setPasscodeTextField.text forKey:@"passcode"]) {
						[KKKeychain setString:@"YES" forKey:@"passcode_on"];
					}
					
					if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
						[_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
					}
					
					[self dismissModalViewControllerAnimated:YES];
				}
			}
		}
	}		 
}

- (void)doneButtonPressed
{	 
	UITextField *textField = [_textFields objectAtIndex:_tableIndex];
	
	if (mode == KKPasscodeModeEnter) {
		NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
		if ([_enterPasscodeTextField.text isEqualToString:passcode]) {
			if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
				[UIView beginAnimations:@"fadeIn" context:nil];
				[UIView setAnimationDelay:0.25];
				[UIView setAnimationDuration:0.5];
				
				[UIView commitAnimations];
			}

			if ([_delegate respondsToSelector:@selector(didPasscodeEnteredCorrectly::)]) {
				[_delegate didPasscodeEnteredCorrectly:self];
			}

			[self dismissModalViewControllerAnimated:YES];
		} else { 
			[self incrementFailedAttemptsLabel];
		}
	} else if (mode == KKPasscodeModeSet) {
		if ([textField isEqual:_setPasscodeTextField]) {
			[self moveToNextTableView];
		} else if ([textField isEqual:_confirmPasscodeTextField]) {
			if (![_confirmPasscodeTextField.text isEqualToString:_setPasscodeTextField.text]) {
				_confirmPasscodeTextField.text = @"";
				_setPasscodeTextField.text = @"";
				_passcodeConfirmationWarningLabel.text = @"Passcodes did not match. Try again.";
				[self moveToPreviousTableView];
			} else {
				if ([KKKeychain setString:_setPasscodeTextField.text forKey:@"passcode"]) {
					[KKKeychain setString:@"YES" forKey:@"passcode_on"];
				}
				
				if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
					[_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
				}
				
				[self dismissModalViewControllerAnimated:YES];
			}
		}						 
	} else if (mode == KKPasscodeModeChange) {
		NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
		if ([textField isEqual:_enterPasscodeTextField]) {
			if ([passcode isEqualToString:_enterPasscodeTextField.text]) {
				[self moveToNextTableView];
			} else {
				[self incrementFailedAttemptsLabel];
			}
		} else if ([textField isEqual:_setPasscodeTextField]) {
			if ([passcode isEqualToString:_setPasscodeTextField.text]) {
				_setPasscodeTextField.text = @"";
				_passcodeConfirmationWarningLabel.text = @"Enter a different passcode. Cannot re-use the same passcode.";
				_passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 131.5, self.view.bounds.size.width, 60.0);
			} else {
				_passcodeConfirmationWarningLabel.text = @"";
				_passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 146.5, self.view.bounds.size.width, 30.0);
				[self moveToNextTableView];
			}
		} else if ([textField isEqual:_confirmPasscodeTextField]) {
			if (![_confirmPasscodeTextField.text isEqualToString:_setPasscodeTextField.text]) {
				_confirmPasscodeTextField.text = @"";
				_setPasscodeTextField.text = @"";
				_passcodeConfirmationWarningLabel.text = @"Passcodes did not match. Try again.";
				[self moveToPreviousTableView];
			} else {
				if ([KKKeychain setString:_setPasscodeTextField.text forKey:@"passcode"]) {
					[KKKeychain setString:@"YES" forKey:@"passcode_on"];
				}
				
				if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
					[_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
				}
				
				[self dismissModalViewControllerAnimated:YES];
			}
		}
	} else if (mode == KKPasscodeModeDisabled) {
		NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
		if ([_enterPasscodeTextField.text isEqualToString:passcode]) {
			if ([KKKeychain setString:@"NO" forKey:@"passcode_on"]) {
				[KKKeychain setString:@"" forKey:@"passcode"];
			}
			
			if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
				[_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
			}
			
			[self dismissModalViewControllerAnimated:YES];
		} else { 
			[self incrementFailedAttemptsLabel];
		}
	}
}

- (UIView*)passwordHeaderViewForTextField:(UITextField*)textField
{
	textField.keyboardType = UIKeyboardTypeNumberPad;
	
	textField.hidden = YES;
	[self.view addSubview:textField];
	
	UIView *headerView = [[[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.bounds.size.width, 70.0)] autorelease];
	UILabel *headerLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0.0, 27.5, self.view.bounds.size.width, 30.0)] autorelease];
	headerLabel.textColor = [UIColor colorWithRed:0.298 green:0.337 blue:0.424 alpha:1.0];
	headerLabel.backgroundColor = [UIColor clearColor];
	headerLabel.textAlignment = UITextAlignmentCenter;
	headerLabel.font = [UIFont boldSystemFontOfSize:17.0];
	headerLabel.shadowOffset = CGSizeMake(0, 1.0);
	headerLabel.shadowColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
	
	if ([textField isEqual:_setPasscodeTextField]) {
		_passcodeConfirmationWarningLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 146.5, self.view.bounds.size.width, 30.0)];
		_passcodeConfirmationWarningLabel.textColor = [UIColor colorWithRed:0.298 green:0.337 blue:0.424 alpha:1.0];
		_passcodeConfirmationWarningLabel.backgroundColor = [UIColor clearColor];
		_passcodeConfirmationWarningLabel.textAlignment = UITextAlignmentCenter;
		_passcodeConfirmationWarningLabel.font = [UIFont systemFontOfSize:14.0];
		_passcodeConfirmationWarningLabel.shadowOffset = CGSizeMake(0, 1.0);
		_passcodeConfirmationWarningLabel.shadowColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
		_passcodeConfirmationWarningLabel.text = @"";
		_passcodeConfirmationWarningLabel.numberOfLines = 0;
		_passcodeConfirmationWarningLabel.lineBreakMode = UILineBreakModeWordWrap;
		[headerView addSubview:_passcodeConfirmationWarningLabel];
	}
	
	if ([textField isEqual:_enterPasscodeTextField]) {
		NSString *text = @"1 Failed Passcode Attempt";
		CGSize size = [text sizeWithFont:[UIFont boldSystemFontOfSize:14.0]];
		_failedAttemptsView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - (size.width + 36.0)) / 2, 147.5, size.width + 36.0, size.height + 10.0)];
		_failedAttemptsLabel = [[UILabel alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - (size.width + 36.0)) / 2, 147.5, size.width + 36.0, size.height + 10.0)]; 
		_failedAttemptsLabel.backgroundColor = [UIColor clearColor];
		_failedAttemptsLabel.textColor = [UIColor whiteColor];
		_failedAttemptsLabel.text = text;
		_failedAttemptsLabel.font = [UIFont boldSystemFontOfSize:14.0];
		_failedAttemptsLabel.textAlignment = UITextAlignmentCenter;
		_failedAttemptsLabel.shadowOffset = CGSizeMake(0, -1.0);
		_failedAttemptsLabel.shadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0];
		_failedAttemptsView.layer.cornerRadius = 14;
		_failedAttemptsView.layer.borderWidth = 1.0;
		_failedAttemptsView.layer.borderColor = [[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.25] CGColor];
		
		_failedAttemptsLabel.hidden = YES;
		_failedAttemptsView.hidden = YES;
		
		CAGradientLayer *gradient = [CAGradientLayer layer];
		gradient.frame = _failedAttemptsView.bounds;				
		gradient.colors = [NSArray arrayWithObjects:(id)[[UIColor colorWithRed:0.714 green:0.043 blue:0.043 alpha:1.0] CGColor], 
											 (id)[[UIColor colorWithRed:0.761 green:0.192 blue:0.192 alpha:1.0] CGColor], nil];
		[_failedAttemptsView.layer insertSublayer:gradient atIndex:1];
		_failedAttemptsView.layer.masksToBounds = YES;
		
		[headerView addSubview:_failedAttemptsView];
		[headerView addSubview:_failedAttemptsLabel];
		
		[_failedAttemptsView release];
		[_failedAttemptsLabel release];
	}
	
	if (mode == KKPasscodeModeSet) {
		self.navigationItem.title = @"Set Passcode";
		UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)];
		self.navigationItem.leftBarButtonItem = cancel;
		[cancel release];
		
		
		if ([textField isEqual:_enterPasscodeTextField]) {
			headerLabel.text = @"Enter your passcode";
		} else if ([textField isEqual:_setPasscodeTextField]) {
			headerLabel.text = @"Enter a passcode";
			UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)];
			self.navigationItem.leftBarButtonItem = cancel;
			[cancel release];
			
		} else if ([textField isEqual:_confirmPasscodeTextField]) {
			headerLabel.text = @"Re-enter your passcode";
		}
	} else if (mode == KKPasscodeModeDisabled) {
		self.navigationItem.title = @"Turn off Passcode";
		UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)];
		self.navigationItem.leftBarButtonItem = cancel;
		[cancel release];
		
		headerLabel.text = @"Enter your passcode";
	} else if (mode == KKPasscodeModeChange) {
		self.navigationItem.title = @"Change Passcode";
		UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)];
		self.navigationItem.leftBarButtonItem = cancel;
		[cancel release];
		
		if ([textField isEqual:_enterPasscodeTextField]) {
			headerLabel.text = @"Enter your old passcode";
		} else if ([textField isEqual:_setPasscodeTextField]) {
			headerLabel.text = @"Enter your new passcode";
		} else {
			headerLabel.text = @"Re-enter your new passcode";
		}
	} else {
		self.navigationItem.title = @"Enter Passcode";
		headerLabel.text = @"Enter your passcode";
	}
	headerLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin;
	
	[headerView addSubview:headerLabel];
	
	return headerView;
}

- (NSArray*)boxes
{
	NSMutableArray *squareViews = [NSMutableArray array];
	
	CGFloat squareX = 0.0;
	
	for (int i = 0; i < kPasscodeBoxesCount; i++) {
		UIImageView *square = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"KKPasscodeLock.bundle/box_empty.png"]];
		square.frame = CGRectMake(squareX, 74.0, kPasscodeBoxWidth, kPasscodeBoxHeight);
		[squareViews addObject:square];
		[square release];
		squareX += 71.0;
	}
	return [NSArray arrayWithArray:squareViews];
}

#pragma mark -
#pragma mark UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView
{
	return 0;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
	return 1;
}

- (UITableViewCell*)tableView:(UITableView*)aTableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
	
	static NSString* CellIdentifier = @"KKPasscodeViewControllerCell";
	
	UITableViewCell* cell = [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	
	if ([aTableView isEqual:_enterPasscodeTableView]) {
		cell.accessoryView = _enterPasscodeTextField;
	} else if ([aTableView isEqual:_setPasscodeTableView]) {
		cell.accessoryView = _setPasscodeTextField;
	} else if ([aTableView isEqual:_confirmPasscodeTableView]) {
		cell.accessoryView = _confirmPasscodeTextField;
	}
	
	return cell;
}


#pragma mark -
#pragma mark UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
	if ([textField isEqual:[_textFields lastObject]]) {
		[self doneButtonPressed];
	} else {
		[self nextDigitPressed];
	}
	return NO;
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	if (YES) {
		NSString *result = [textField.text stringByReplacingCharactersInRange:range withString:string];
		textField.text = result;
		
		for (int i = 0; i < kPasscodeBoxesCount; i++) {
			UIImageView *square = [[_boxes objectAtIndex:_tableIndex] objectAtIndex:i];
			if (i < [result length]) {
				square.image = [UIImage imageNamed:@"KKPasscodeLock.bundle/box_filled.png"];
			} else {
				square.image = [UIImage imageNamed:@"KKPasscodeLock.bundle/box_empty.png"];
			}
		}
		
		if ([result length] == kPasscodeBoxesCount) {
			
			if (mode == KKPasscodeModeDisabled) {
				NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
				if ([_enterPasscodeTextField.text isEqualToString:passcode]) {
					if ([KKKeychain setString:@"NO" forKey:@"passcode_on"]) {
						[KKKeychain setString:@"" forKey:@"passcode"];
					}
					
					if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
						[_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
					}
					
					[self dismissModalViewControllerAnimated:YES];
				} else { 
					[self incrementFailedAttemptsLabel];
				}
			} else if (mode == KKPasscodeModeEnter) {
				NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
				if ([_enterPasscodeTextField.text isEqualToString:passcode]) {
					if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
						[UIView beginAnimations:@"fadeIn" context:nil];
						[UIView setAnimationDelay:0.25];
						[UIView setAnimationDuration:0.5];
						
						[UIView commitAnimations];
					}
					if ([_delegate respondsToSelector:@selector(didPasscodeEnteredCorrectly:)]) {
						[_delegate performSelector:@selector(didPasscodeEnteredCorrectly:) withObject:self];
					}
					
					[self dismissModalViewControllerAnimated:YES];
				} else { 
					[self incrementFailedAttemptsLabel];
				}
			} else if (mode == KKPasscodeModeChange) {
				NSString *passcode = [KKKeychain getStringForKey:@"passcode"];
				if ([textField isEqual:_enterPasscodeTextField]) {
					if ([passcode isEqualToString:_enterPasscodeTextField.text]) {
						[self moveToNextTableView];
					} else {
						[self incrementFailedAttemptsLabel];
					}
				} else if ([textField isEqual:_setPasscodeTextField]) {
					if ([passcode isEqualToString:_setPasscodeTextField.text]) {
						_setPasscodeTextField.text = @"";
						for (int i = 0; i < kPasscodeBoxesCount; i++) {
							[[[_boxes objectAtIndex:_tableIndex] objectAtIndex:i] setImage:[UIImage imageNamed:@"KKPasscodeLock.bundle/box_empty.png"]];
						}		 
						_passcodeConfirmationWarningLabel.text = @"Enter a different passcode. Cannot re-use the same passcode.";
						_passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 131.5, self.view.bounds.size.width, 60.0);
					} else {
						_passcodeConfirmationWarningLabel.text = @"";
						_passcodeConfirmationWarningLabel.frame = CGRectMake(0.0, 146.5, self.view.bounds.size.width, 30.0);
						[self moveToNextTableView];
					}
				} else if ([textField isEqual:_confirmPasscodeTextField]) {
					if (![_confirmPasscodeTextField.text isEqualToString:_setPasscodeTextField.text]) {
						_confirmPasscodeTextField.text = @"";
						_setPasscodeTextField.text = @"";
						_passcodeConfirmationWarningLabel.text = @"Passcodes did not match. Try again.";
						[self moveToPreviousTableView];
					} else {
						if ([KKKeychain setString:_setPasscodeTextField.text forKey:@"passcode"]) {
							[KKKeychain setString:@"YES" forKey:@"passcode_on"];
						}
						
						if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
							[_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
						}
						
						[self dismissModalViewControllerAnimated:YES];
					}
				}
			} else if ([textField isEqual:_setPasscodeTextField]) {
				[self moveToNextTableView];
			} else if ([textField isEqual:_confirmPasscodeTextField]) {
				if (![_confirmPasscodeTextField.text isEqualToString:_setPasscodeTextField.text]) {
					_confirmPasscodeTextField.text = @"";
					_setPasscodeTextField.text = @"";
					_passcodeConfirmationWarningLabel.text = @"Passcodes did not match. Try again.";
					[self moveToPreviousTableView];
				} else {
					if ([KKKeychain setString:_setPasscodeTextField.text forKey:@"passcode"]) {
						[KKKeychain setString:@"YES" forKey:@"passcode_on"];
					}
					if ([_delegate respondsToSelector:@selector(didSettingsChanged:)]) {
						[_delegate performSelector:@selector(didSettingsChanged:) withObject:self];
					}
					[self dismissModalViewControllerAnimated:YES];
				}
			}
		}
		return NO;
	}
	
	return YES;
}


#pragma mark -
#pragma mark Memory management

- (void)dealloc 
{	 
  [_enterPasscodeTableView release];
  [_setPasscodeTableView release];
  [_confirmPasscodeTableView release];
  
	[_enterPasscodeTextField release];
	[_setPasscodeTextField release];
	[_confirmPasscodeTextField release];
	[_tableViews release];
	[_textFields release];
	[_boxes release];
	[super dealloc];
}

@end
