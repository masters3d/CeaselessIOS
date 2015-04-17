//
//  AppDelegate.m
//  Ceaseless
//
//  Created by Christopher Lim on 3/2/15.
//  Copyright (c) 2015 Christopher Lim. All rights reserved.
//

#import "AppDelegate.h"
#import "AppConstants.h"
#import "TAGContainer.h"
#import "TAGContainerOpener.h"
#import "TAGManager.h"

@interface AppDelegate ()<TAGContainerOpenerNotifier>
// Used for sending traffic in the background.
@property(nonatomic, assign) BOOL okToWait;
@property(nonatomic, copy) void (^dispatchHandler)(TAGDispatchResult result);
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // analytics
    self.tagManager = [TAGManager instance];
    
    // Modify the log level of the logger to print out not only
    // warning and error messages, but also verbose, debug, info messages.
    
    [self.tagManager.logger setLogLevel:kTAGLoggerLogLevelVerbose];
    
    // Following provides ability to support preview from Tag Manager.
    // You need to make these calls before opening a container to make
    // preview works.
    NSURL *url = [launchOptions valueForKey:UIApplicationLaunchOptionsURLKey];
    if (url != nil) {
        [self.tagManager previewWithUrl:url];
    }

    /*
     * Opens a container.
     *
     * @param containerId The ID of the container to load.
     * @param tagManager The TAGManager instance for getting the container.
     * @param openType The choice of how to open the container.
     * @param timeout The timeout period (default is 2.0 seconds).
     * @param notifier The notifier to inform on container load events.
     */
    [TAGContainerOpener openContainerWithId:@"GTM-KP4WD6"
                                 tagManager:self.tagManager
                                   openType:kTAGOpenTypePreferFresh
                                    timeout:nil
                                   notifier:self];
    
    // Override point for customization after application launch.
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];

	NSDictionary *navbarTitleTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
											   [UIColor whiteColor], NSForegroundColorAttributeName,
											   [UIFont fontWithName:@"AvenirNext-Medium" size:16.0f],NSFontAttributeName,
											   nil];

	[[UINavigationBar appearance] setTitleTextAttributes:navbarTitleTextAttributes];

    // TODO we may want to re-think if we want to ask for local notification permission when the app opens.
    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound categories:nil]];
    }

    return YES;
}

// TAGContainerOpenerNotifier callback.
- (void)containerAvailable:(TAGContainer *)container {
    // Note that containerAvailable may be called on any thread, so you may need to dispatch back to
    // your main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        self.container = container;
    });
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    if ([self.tagManager previewWithUrl:url]) {
        return YES;
    }
    
    // Code to handle other urls.
    
    return NO;
}

// In case the app was sent into the background when there was no network connection, we will use
// the background data fetching mechanism to send any pending Google Analytics data.  Note that
// this app has turned on background data fetching in the capabilities section of the project.
-(void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [self sendHitsInBackground];
    completionHandler(UIBackgroundFetchResultNewData);
}

// This method sends hits in the background until either we're told to stop background processing,
// we run into an error, or we run out of hits.
- (void)sendHitsInBackground {
    self.okToWait = YES;
    __weak AppDelegate *weakSelf = self;
    __block UIBackgroundTaskIdentifier backgroundTaskId =
    [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        weakSelf.okToWait = NO;
    }];
    
    if (backgroundTaskId == UIBackgroundTaskInvalid) {
        return;
    }
    
    self.dispatchHandler = ^(TAGDispatchResult result) {
        // If the last dispatch succeeded, and we're still OK to stay in the background then kick off
        // again.
        if (result == kTAGDispatchGood && weakSelf.okToWait ) {
            [[TAGManager instance] dispatchWithCompletionHandler:weakSelf.dispatchHandler];
        } else {
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
        }
    };
    [[TAGManager instance] dispatchWithCompletionHandler:self.dispatchHandler];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

    // scheduling local notifications
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    
    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSCalendarIdentifierGregorian];

	NSDate *notificationDate;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults objectForKey:kNotificationDate]) {
        NSDate *now = [NSDate date];
        NSDateComponents *dateComponent = [gregorian components:NSCalendarUnitYear | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitWeekday | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour fromDate: now];
        
        dateComponent.hour = 8; // the default notification time is 8am.
        dateComponent.minute = 0;
        dateComponent.second = 0;
        notificationDate = [[NSCalendar currentCalendar] dateFromComponents:dateComponent];
        [defaults setObject:notificationDate forKey:kNotificationDate];
        [defaults synchronize];
    } else {
        notificationDate = [defaults objectForKey:kNotificationDate];
    }
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    [notification setAlertBody:@"Remember to pray for others today."];
    [notification setFireDate:notificationDate];
    notification.repeatInterval = NSCalendarUnitWeekday;
    [notification setTimeZone:[NSTimeZone defaultTimeZone]];
	[notification setSoundName: UILocalNotificationDefaultSoundName];
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
    
    // We'll try to dispatch any hits queued for dispatch as the app goes into the background.
    [self sendHitsInBackground];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Core Data stack

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (NSURL *)applicationDocumentsDirectory {
		// The directory the application uses to store the Core Data store file. This code uses a directory named "com.Frostbite-Learning.CoreDataTemplate" in the application's documents directory.
	return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSManagedObjectModel *)managedObjectModel {
		// The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
	if (_managedObjectModel != nil) {
		return _managedObjectModel;
	}
	NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Ceaseless" withExtension:@"momd"];
	_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];

	return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
		// The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it.
	if (_persistentStoreCoordinator != nil) {
		return _persistentStoreCoordinator;
	}

		// Create the coordinator and store

	_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
	NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Ceaseless.sqlite"];
	NSError *error = nil;
	NSString *failureReason = @"There was an error creating or loading the application's saved data.";
	if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
			// Report any error we got.
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
		dict[NSLocalizedFailureReasonErrorKey] = failureReason;
		dict[NSUnderlyingErrorKey] = error;
		error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
			// Replace this with code to handle the error appropriately.
			// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
	}

	return _persistentStoreCoordinator;
}


- (NSManagedObjectContext *)managedObjectContext {
		// Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
	if (_managedObjectContext != nil) {
		return _managedObjectContext;
	}

	NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	if (!coordinator) {
		return nil;
	}
	_managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSMainQueueConcurrencyType];
	[_managedObjectContext setPersistentStoreCoordinator:coordinator];
	return _managedObjectContext;
}

#pragma mark - Core Data Saving support

- (void)saveContext {
	NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
	if (managedObjectContext != nil) {
		NSError *error = nil;
		if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
				// Replace this implementation with code to handle the error appropriately.
				// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
			NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
			abort();
		}
	}
}

@end
