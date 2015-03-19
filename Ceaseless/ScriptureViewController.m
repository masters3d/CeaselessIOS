//
//  ScriptureViewController.m
//  Ceaseless
//
//  Created by Christopher Lim on 3/6/15.
//  Copyright (c) 2015 Christopher Lim. All rights reserved.
//

#import "ScriptureViewController.h"
#import "ScriptureQueue.h"
#import "AppDelegate.h"

@interface ScriptureViewController ()

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end

@implementation ScriptureViewController

- (void)viewDidLoad {
	[super viewDidLoad];
		// Do any additional setup after loading the view, typically from a nib.
	[self formatCardView: self.scriptureView.cardView withShadowView:self.scriptureView.shadowView];
}
- (void)viewWillAppear: (BOOL)animated {
    [super viewWillAppear:animated];

	AppDelegate *appDelegate = (id) [[UIApplication sharedApplication] delegate];
	self.managedObjectContext = appDelegate.managedObjectContext;

	self.scriptureView.scriptureReferenceLabel.text = [self.dataObject valueForKey: @"citation" ];
	self.scriptureView.scriptureTextView.text = [self.dataObject valueForKey: @"verse"];
		//scroll text to top of view
	[self.scriptureView.scriptureTextView scrollRangeToVisible: (NSMakeRange(0, 0))];
}
- (IBAction)share:(id)sender {
    NSString *contentToShare = [NSString stringWithFormat:@"%@ %@", [self.dataObject valueForKey: @"verse"], [self.dataObject valueForKey: @"shareLink"]];
    
    NSArray *objectsToShare = @[contentToShare]; // string and url is what we need to show.
    
    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:objectsToShare  applicationActivities:nil];
    // iPads need an anchor point for the popover view.
    // http://stackoverflow.com/questions/25644054/uiactivityviewcontroller-crashing-on-ios8-ipads
    controller.popoverPresentationController.sourceView = self.scriptureView;
    CGRect rect = self.scriptureView.frame;
    controller.popoverPresentationController.sourceRect = CGRectMake(rect.size.width, rect.size.height-42, 1, 1);
    controller.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionDown;
    
    // Present the controller
    [self presentViewController:controller animated:YES completion:nil];
    
}
@end
