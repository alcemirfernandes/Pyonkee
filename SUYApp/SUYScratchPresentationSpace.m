//
//  SUYScratchPresentationSpace.m
//  ScratchOnIPad
//
//  Created by Masashi UMEZAWA on 2014/06/20
//  Modified, customized version of ScratchIPhonePresentationSpace.m
//
//  Originally Created by John M McIntosh on 10-02-15.
//  Copyright 2010 Corporate Smalltalk Consulting Ltd. All rights reserved.
//
//  

#import "SUYScratchPresentationSpace.h"
#import "SUYScratchAppDelegate.h"
#import "SqueakUIController.h"
#import "sqSqueakIPhoneInfoPlistInterface.h"

#import "SUYUtils.h"
#import "SUYFontResizeViewController.h"
#import "SUYCameraViewController.h"
#import "SUYWebViewController.h"

#import <QuartzCore/QuartzCore.h>

extern ScratchIPhoneAppDelegate *gDelegateApp;
static const int kCommandAutoUpSeconds = 2;
static const int kShiftAutoUpSeconds = 20;

@implementation ScratchIPhonePresentationSpace
@synthesize scrollView,scrollViewController,fontScaleButton, radioButtonSetController,
	textField,pathToProjectFile,repeatKeyDict,
    softKeyboardField, softKeyboardOnButton,
	shoutGoLandscapeButton,stopAllLandscapeButton,landscapeToolBar,landscapeToolBar2,padLockButton,
    commandButton, shiftButton,
	indicatorView, popUpInfoViewController, viewModeBar, presentationExitButton;

BOOL useIme = NO;
int originalEditModeIndex = 1;

uint warningMinHeapThreshold;
uint memoryWarningCount;

#pragma mark Initialization
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		repeatKeyDict = [[NSMutableDictionary alloc] init];
	}
    return self;
}


#pragma mark View Callback
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];

	self.textField.keyboardAppearance = UIKeyboardAppearanceAlert;
    self.softKeyboardField.hidden = YES;
	 
	[self.scrollView addSubview: gDelegateApp.mainView];
    self.scrollView.contentSize = gDelegateApp.mainView.bounds.size;
    
    self.viewModeBar.layer.cornerRadius = 5;
    self.viewModeBar.layer.masksToBounds = YES;
    
    [self.scrollView setZoomScale: [SUYUtils scratchScreenZoomScale] animated: NO];
    self.scrollView.minimumZoomScale = [SUYUtils scratchScreenZoomScale];
    self.scrollView.maximumZoomScale = 8;
    [self.scrollView flashScrollIndicators];
    
    //originalEditModeIndex = 1;
    
    warningMinHeapThreshold = [gDelegateApp squeakMaxHeapSize] * 0.70;
    memoryWarningCount = 0;
}

- (void) viewWillAppear:(BOOL)animated {
	[[UIApplication sharedApplication] setStatusBarHidden: YES withAnimation: UIStatusBarAnimationFade];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible: NO];
	[gDelegateApp.viewController setNavigationBarHidden: YES animated: YES];
	
	self.scrollView.delaysContentTouches = self.padLockButton.selected;
    self.radioButtonSetController.selectedIndex = originalEditModeIndex;
    [self keyboardDidChange:nil];
    [self listenNotifications];
    
	[super viewWillAppear: animated];
}

- (void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear: animated];
    if ([gDelegateApp restartCount] == 0) {
        [self firstViewDidAppear];
	} else {
        [self restartedViewDidAppear];
    }
}

- (void) viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear: animated];
    [self forgetNotifications];
}

#pragma mark Notifications
- (void)listenNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidChange:)
												 name:UITextInputCurrentInputModeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(softKeyboardDeactivate:)
												 name:@"SqueakUIViewTouchesBegan" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(softKeyboardDeactivate:)
												 name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scratchDialogOpened:)
												 name:@"ScratchDialogOpened" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scratchDialogClosed:)
												 name:@"ScratchDialogClosed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scratchProjectReloaded:)
												 name:@"ScratchProjectReloaded" object:nil];
}

- (void)forgetNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextInputCurrentInputModeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SqueakUIViewTouchesBegan" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ScratchDialogOpened" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ScratchDialogClosed" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ScratchProjectReloaded" object:nil];
}


#pragma mark View Opening
- (void) firstViewDidAppear{
    [[self appDelegate] openProject: @"" run: NO];
}

- (void) restartedViewDidAppear{
    [SUYUtils inform:(NSLocalizedString(@"Done!",nil)) duration:400 for:self];
    [[self appDelegate] openProject: @"" run: NO];
}

- (void) postOpen {
	[self performSelectorOnMainThread:@selector(postOpenOnMainThread) withObject: nil waitUntilDone: NO];
}

- (void) postOpenOnMainThread {
	[gDelegateApp terminateActivityView];
}

#pragma mark Rotation
- (BOOL)shouldAutorotate {
	return YES;
}

- (NSUInteger)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskLandscape;
}


#pragma mark Actions

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.fontScaleButton.selected = NO;
	self.popUpInfoViewController = nil;
}

- (IBAction) openCamera:(id)sender clientMode:(NSString *)clientMode{
    SUYCameraViewController *viewController = [[SUYCameraViewController alloc] initWithNibName:@"SUYCameraViewController" bundle:nil];
    viewController.modalPresentationStyle = UIModalPresentationFormSheet;
    viewController.clientMode = clientMode;
    [self presentViewController:viewController animated:YES completion:NULL];
}

- (IBAction) openHelp:(id)sender url:(NSString *)url {
    SUYWebViewController *viewController = [[SUYWebViewController alloc] initWithNibName:@"SUYWebViewController" bundle:nil];
    viewController.modalPresentationStyle = UIModalPresentationPageSheet;
    viewController.initialUrl = url;
    [self presentViewController:viewController animated:YES completion:NULL];
    
}

- (IBAction) showWaitIndicator {
    if(indicatorView != null){return;}
    indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    indicatorView.hidesWhenStopped = YES;
    [self.view addSubview:indicatorView];
    indicatorView.center = self.view.center;
    [indicatorView startAnimating];
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
}

- (IBAction) hideWaitIndicator {
    if(indicatorView == null){return;}
    [indicatorView stopAnimating];
    [indicatorView removeFromSuperview];
    indicatorView = nil;
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
}


- (IBAction) openFontResizer:(id)sender {
    if(self.viewModeIndex == 2){return;}
    
    self.fontScaleButton.selected = YES;
	SUYFontResizeViewController *fontResizeController = [[SUYFontResizeViewController alloc] initWithNibName:@"SUYFontResizeViewController" bundle:[NSBundle mainBundle]];
    
	Class UIPopoverControllerClass = NSClassFromString(@"UIPopoverController");
	popUpInfoViewController  = [[UIPopoverControllerClass alloc] initWithContentViewController: fontResizeController];
	self.popUpInfoViewController.delegate = self;
	[self.popUpInfoViewController setPopoverContentSize: CGSizeMake(320.0f,80.0f) animated: YES];
	[self.popUpInfoViewController presentPopoverFromRect: self.fontScaleButton.frame inView: self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated: YES];

}


- (IBAction) operatePadLock: (id) sender {
	self.padLockButton.selected = !self.padLockButton.selected;
	self.scrollView.delaysContentTouches = self.padLockButton.selected;  // padlock is open (aka selected) so we delay
}

- (IBAction) shoutGo:(id)sender {
	self.shoutGoLandscapeButton.selected = YES;
	self.stopAllLandscapeButton.selected = NO;
    dispatch_async (
        dispatch_get_main_queue(),
        ^{
           [[self appDelegate] shoutGo];
         }
    );
}

- (IBAction) stopAll:(id)sender {
	self.shoutGoLandscapeButton.selected =  NO;
	self.stopAllLandscapeButton.selected = YES;
    dispatch_async (
        dispatch_get_main_queue(),
        ^{
           [[self appDelegate] stopAll];
        }
    );
}

- (IBAction) exitPresentation:(id)sender{
    self.radioButtonSetController.selectedIndex = originalEditModeIndex;
    self.presentationExitButton.hidden = YES;
    self.viewModeBar.hidden = NO;
    dispatch_async (
         dispatch_get_main_queue(),
         ^{
              [[self appDelegate] exitPresentationMode];
          }
    );
}

- (IBAction) softKeyboardActivate:(id)sender {
    self.softKeyboardField.hidden = NO;
    [softKeyboardField becomeFirstResponder];
}

- (IBAction) softKeyboardDeactivate: (id) sender{
    self.softKeyboardField.hidden = YES;
    [softKeyboardField resignFirstResponder];
}

- (IBAction) commandButtonUp:(id)sender {
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(basicCommandButtonAutoUp:) object:sender];
    [self performSelector:@selector(basicCommandButtonAutoUp:) withObject:sender afterDelay: kCommandAutoUpSeconds];
}

- (IBAction) commandButtonDown:(id)sender {
	self.commandButton.selected = YES;
	[[self appDelegate] commandKeyStateChanged: 1];
}

- (IBAction) basicCommandButtonAutoUp:(id)sender {
	self.commandButton.selected =  NO;
    [[self appDelegate] commandKeyStateChanged: 0];
}

- (IBAction) shiftButtonUp:(id)sender {
    if(self.shiftButton.selected == YES){
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(basicShiftButtonAutoUp:) object:sender];
        [self performSelector:@selector(basicShiftButtonAutoUp:) withObject:sender afterDelay: kShiftAutoUpSeconds];
    } else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(basicShiftButtonAutoUp:) object:sender];
    }
}

- (IBAction) shiftButtonDown:(id)sender {
	self.shiftButton.selected =  !self.shiftButton.selected;
	[[self appDelegate] shiftKeyStateChanged: shiftButton.selected];
}

- (IBAction) basicShiftButtonAutoUp:(id)sender {
    self.shiftButton.selected =  NO;
    LgInfo(@"!!! shiftButtonAutoUp !!!");
    [[self appDelegate] shiftKeyStateChanged: NO];
}


#pragma mark Accessing
- (int) viewModeIndex {
    return self.radioButtonSetController.selectedIndex;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
	return gDelegateApp.mainView;
}

- (ScratchIPhoneAppDelegate*) appDelegate{
    return (ScratchIPhoneAppDelegate*) gDelegateApp;
}

#pragma mark TextEdit

- (void)keyboardDidChange:(NSNotification*)sender{
    LgInfo(@"keyboardDidChange");
    self.softKeyboardField.text = @"";
    NSString *primLang = [self inputModePrimaryLanguage];
    if(
       ([primLang rangeOfString:@"ja-"].location != NSNotFound) ||
       ([primLang rangeOfString:@"ko-"].location != NSNotFound) ||
       ([primLang rangeOfString:@"zh-"].location != NSNotFound)) {
        LgInfo(@"ime mode = %@", primLang);
        self.softKeyboardField.autocorrectionType = UITextAutocorrectionTypeDefault;
        self.softKeyboardField.frame = CGRectMake(292, 324, 440, 32);
        useIme = YES;
    } else {
        LgInfo(@"non ime = %@", primLang);
        self.softKeyboardField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.softKeyboardField.frame = CGRectMake(292, 366, 380, 40);
        useIme = NO;
    }
 }


- (BOOL)textFieldShouldBeginEditing:(UITextField *) aTextField {
    if(aTextField == self.softKeyboardField){
        aTextField.text = @"";
    }
    if(aTextField == self.textField){
        aTextField.text = @" ";
        characterCounter = 0;
    }
	return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *) aTextField {
    if(aTextField == self.softKeyboardField){
        self.softKeyboardField.hidden = YES;
        [self flushInputString: self.softKeyboardField.text];
    }
    [aTextField resignFirstResponder];
    characterCounter = 0;
    
    if(aTextField == self.textField){
        aTextField.text = @" ";
    } else {
        aTextField.text = @"";
    }
	return YES;
}

-(void)flushInputString:(NSString*) processedString {
    if(useIme == NO) {return;}
    LgInfo(@"!!! flushInputString %@", processedString);
    [gDelegateApp.mainView recordCharEvent: processedString];
}

- (BOOL)textField:(UITextField *) aTextField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)rstr {
	if(aTextField == self.textField){
        return [self nonImeTextField:aTextField shouldChangeCharactersInRange:range replacementString:rstr];
    }
    if(aTextField == self.softKeyboardField){
        if(useIme == NO){
            [self nonImeTextField:aTextField shouldChangeCharactersInRange:range replacementString:rstr];
        }
        return YES;
    }
	return NO;
}

- (BOOL)nonImeTextField:(UITextField *) aTextField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)rstr {
    const unichar delete = 0x08;
	if ([rstr length] > 0 && [rstr characterAtIndex: 0] == (unichar) 10) {
		[aTextField resignFirstResponder];
		aTextField.text = @"";
		[gDelegateApp.mainView recordCharEvent: rstr];
		return NO;
	}
	if ([rstr length] == 0) {
		
		[gDelegateApp.mainView recordCharEvent: [NSString stringWithCharacters: &delete length: 1] ];
	} else {
        if(range.length > 0){
            //[gDelegateApp.mainView recordCharEvent: rstr]; //TODO: fix previous text
        } else {
            [gDelegateApp.mainView recordCharEvent: rstr];
        }
	}
    return NO;
}


- (void) textMorphFocused: (BOOL)status{
    if((status == YES) && (softKeyboardField.hidden))
    {
        [self performSelectorOnMainThread:@selector(softKeyboardActivate:) withObject: nil waitUntilDone: NO];
    }
}

- (NSString *)inputModePrimaryLanguage {
    UITextInputMode *inputMode = [UITextInputMode currentInputMode];
    if(inputMode == nil){ return @"";}
    NSString *primLang = [inputMode primaryLanguage];
    return primLang;
}

#pragma mark Key Handling

- (void) pushCharacter: (NSString*) string {
	[gDelegateApp.mainView recordCharEvent: string];
}

- (void)repeatKeyDoKey:(NSTimer*)theTimer {
	[self pushCharacter: [[theTimer userInfo] string]];
}

- (void)repeatKeySecondPhase:(NSTimer*)theTimer {
	[self repeatKeyDoKey: theTimer];
	NSNumber *senderHash = [[theTimer userInfo] senderHash];
	@synchronized(self) {
		NSTimer *newTimer = [NSTimer scheduledTimerWithTimeInterval:0.05f target:self 
															 selector:@selector(repeatKeyDoKey:) 
												  userInfo: [theTimer userInfo] repeats:YES];
		[self.repeatKeyDict removeObjectForKey: senderHash];
		[self.repeatKeyDict setObject:newTimer forKey: senderHash];
	}
}

- (void) startRepeatKeyAction: (NSString*) string  for: (id) sender {
	@synchronized(self) {
		ScratchRepeatKeyMetaData *stub = [[ScratchRepeatKeyMetaData alloc] init];
		stub.string = string;
		stub.senderHash = [NSNumber numberWithUnsignedInteger:[sender hash]] ;
		NSTimer *repeatKeyTimerInstance = [NSTimer scheduledTimerWithTimeInterval:0.2f target:self 
															 selector:@selector(repeatKeySecondPhase:) 
											  userInfo: stub repeats:NO];
		[self.repeatKeyDict setObject:repeatKeyTimerInstance forKey: stub.senderHash];
	}
}

- (IBAction) keySpace: (id) sender {
	BOOL spaceRepeats = [(sqSqueakIPhoneInfoPlistInterface*) gDelegateApp.squeakApplication.infoPlistInterfaceLogic spaceRepeats];
	if (spaceRepeats) {
		unichar character = 32;
		[self startRepeatKeyProcess: character for: sender];
	} else {
		[self pushCharacter: @" "];
	}
}

- (IBAction) keyTouchUp:(id)sender {
	@synchronized(self) {
		NSNumber *senderHash = [NSNumber numberWithUnsignedInteger:[sender hash]];
		NSTimer *repeatKeyTimerInstance = [self.repeatKeyDict objectForKey: senderHash];
		if (repeatKeyTimerInstance) {
			[repeatKeyTimerInstance invalidate];
			[self.repeatKeyDict removeObjectForKey: senderHash];
		}
	}
}

- (void) startRepeatKeyProcess: (unichar) character for: (id) sender {
	NSString *string = [[NSString alloc] initWithCharacters:&character length: 1];
	[self pushCharacter: string];
	[self startRepeatKeyAction: string for: sender];
}

- (IBAction) keyUpArrow:(id)sender {
	unichar character = 30;
	[self startRepeatKeyProcess: character for: sender];
}

- (IBAction) keyDownArrow:(id)sender {
	unichar character = 31;
	[self startRepeatKeyProcess: character for: sender];
}

- (IBAction) keyLeftArrow:(id)sender {
	unichar character = 28;
	[self startRepeatKeyProcess: character for: sender];
}

- (IBAction) keyRightArrow:(id)sender {
	unichar character = 29;
	[self startRepeatKeyProcess: character for: sender];
}

#pragma mark View Mode
- (void)changedViewModeIndex:(NSUInteger)selectedIndex
{
    if(selectedIndex <= 1){
        originalEditModeIndex = selectedIndex;
    } else {
        self.presentationExitButton.hidden = NO;
        self.viewModeBar.hidden = YES;
    }
}

- (void)radioButtonSetController:(GSRadioButtonSetController *)controller didSelectButtonAtIndex:(NSUInteger)selectedIndex
{
    [self changedViewModeIndex:selectedIndex];
    [self setViewModeIndex:selectedIndex];
}

- (void)setViewModeIndex:(int)selectedIndex
{
    dispatch_async (
          dispatch_get_main_queue(),
           ^{
               [[self appDelegate] setViewModeIndex: selectedIndex];
            }
    );
    
}

#pragma mark Callback from Scratch

- (void)scratchDialogOpened:(id)sender
{
    dispatch_async (
         dispatch_get_main_queue(),
         ^{
             [UIView transitionWithView:self.viewModeBar
                               duration:0.6
                                options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                             animations:NULL
                             completion:NULL];
             self.viewModeBar.hidden = YES;
          }
    );
}

- (void)scratchDialogClosed:(id)sender
{
    dispatch_async (
        dispatch_get_main_queue(),
        ^{
            self.viewModeBar.alpha = 0;
            self.viewModeBar.hidden = NO;
            [UIView animateWithDuration:0.3 animations:^{
                self.viewModeBar.alpha = 1;
            }];
        }
    );
}

-(void) scratchProjectReloaded:(id)sender
{
    dispatch_async (
        dispatch_get_main_queue(),
        ^{
            [self changedViewModeIndex:[[self appDelegate] getViewModeIndex]];
        }
    );
}


#pragma mark Releasing

- (void)dealloc {
	@synchronized(self) {
		for (NSTimer *e in [self.repeatKeyDict allValues]) {
			[e invalidate];
		}
	}
}

- (void)didReceiveMemoryWarning {
    memoryWarningCount++;
    
	[super didReceiveMemoryWarning];
    
    int bytesLeft = [gDelegateApp squeakMemoryBytesLeft];
    LgInfo(@"  --- SqueakMemoryBytesLeft: %d", bytesLeft);
    LgInfo(@"  --- warningMinHeapThreshold: %d", warningMinHeapThreshold);
    LgInfo(@"$$$ RestartCount:%d", [[self appDelegate] restartCount]);
    
    int minCount = 2 - [[self appDelegate] restartCount];
    if(minCount <= 0){minCount = 1;}
    
    if(memoryWarningCount > minCount){
       LgInfo(@"$$$ - memoryWarningCount restart");
       [[self appDelegate] restartVm];
    } else if(warningMinHeapThreshold > bytesLeft){
       LgInfo(@"$$$ - warningHeapThreshold restart");
       [[self appDelegate] restartVm];
    } else {
        LgInfo(@"$$$ - ignored memory warning...");
    }

}


@end