//
//  PrayerJournalViewController.m
//  Ceaseless
//
//  Created by Lori Hill on 3/12/15.
//  Copyright (c) 2015 Christopher Lim. All rights reserved.
//

#import "PrayerJournalViewController.h"
#import "NoteViewController.h"
#import "AppDelegate.h"
#import "PrayerJournalTableViewCell.h"
#import "CeaselessLocalContacts.h"
#import "NonMOPerson.h"
#import "Person.h"
#import "Name.h"
#import "AppUtils.h"

typedef NS_ENUM(NSInteger, PrayerJournalSearchScope)
{
	searchScopeFriends = 0,
	searchScopeMe = 1
};

@interface PrayerJournalViewController () <NSFetchedResultsControllerDelegate, UISearchBarDelegate, UISearchResultsUpdating>

@property (strong, nonatomic) NSArray *filteredList;
@property (strong, nonatomic) NSFetchRequest *searchFetchRequest;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) CeaselessLocalContacts *ceaselessContacts;


@end

@implementation PrayerJournalViewController

- (void)awakeFromNib {
	[super awakeFromNib];
	AppDelegate *appDelegate = (id) [[UIApplication sharedApplication] delegate];
	self.managedObjectContext = appDelegate.managedObjectContext;
    self.ceaselessContacts = [CeaselessLocalContacts sharedCeaselessLocalContacts];
}

- (void)viewDidLoad {
	[super viewDidLoad];
		// Do any additional setup after loading the view, typically from a nib.
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.tableView.frame];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    UIImage *backgroundImage = [AppUtils getDynamicBackgroundImage];
    if(backgroundImage != nil) {
        imageView.image = backgroundImage;
    } else {
        imageView.image = [UIImage imageNamed:@"Screen Shot 2015-02-18 at 8.22.42 AM.png"];
    }
	
	self.tableView.backgroundView = imageView;

	self.tableView.estimatedRowHeight = 130.0;
	self.tableView.rowHeight = UITableViewAutomaticDimension;

		//searchController cannot be set up in IB, so set it up here
	self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
	self.searchController.searchResultsUpdater = self;
	self.searchController.dimsBackgroundDuringPresentation = NO;
	self.searchController.searchBar.barTintColor = UIColorFromRGBWithAlpha(0x24292f , 0.4);
	self.searchController.searchBar.tintColor = [UIColor whiteColor];
	self.searchController.searchBar.scopeButtonTitles = @[NSLocalizedString(@"Friends",@"Friends"),
														  NSLocalizedString(@"Me",@"Me")];
	self.searchController.searchBar.delegate = self;
//		// Hide the search bar until user scrolls up
	CGRect newBounds = self.tableView.bounds;
	newBounds.origin.y = newBounds.origin.y + self.searchController.searchBar.bounds.size.height;
	self.tableView.bounds = newBounds;

	self.tableView.tableHeaderView = self.searchController.searchBar;
	self.definesPresentationContext = YES;

}
- (void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear: animated];

}

- (void) viewWillDisappear:(BOOL)animated {
	[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:animated];
	[super viewWillDisappear:animated];
}
- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
		// Dispose of any resources that can be recreated.
	self.searchFetchRequest = nil;

}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([[segue identifier] isEqualToString:@"ShowNote"]) {
		Note *currentNote = nil;

		if (self.searchController.isActive) {
			NSIndexPath *indexPath = [((UITableViewController *)self.searchController.searchResultsController).tableView indexPathForSelectedRow];
			currentNote = [self.filteredList objectAtIndex:indexPath.row];
		} else {

			NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
			currentNote = [self.fetchedResultsController objectAtIndexPath:indexPath];
		}

		self.noteViewController = segue.destinationViewController;
		self.noteViewController.currentNote = currentNote;
	}
}
- (IBAction)unwindToPrayerJournal:(UIStoryboardSegue*)sender
{
		// Pull any data from the view controller which initiated the unwind segue.
	[self.tableView reloadData];
}
#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	if (self.searchController.active) {
		return 1;
	} else {
		return [[self.fetchedResultsController sections] count];
	}
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (self.searchController.active) {
		return [self.filteredList count];
	} else {
		id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
		return [sectionInfo numberOfObjects];
	}
}
- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 0;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	PrayerJournalTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

	[self configureCell:cell atIndexPath:indexPath];
	return cell;
}

- (void)configureCell:(PrayerJournalTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {

	Note *note = nil;
	if (self.searchController.active) {
		note = [self.filteredList objectAtIndex:indexPath.row];
	} else {
		note = [self.fetchedResultsController objectAtIndexPath:indexPath];
	}


	NSArray *peopleArray = [note.peopleTagged allObjects];

	if ([peopleArray count] > 0) {
        NonMOPerson *nonMOPerson = [self.ceaselessContacts getNonMOPersonForCeaselessContact:[peopleArray firstObject]];
		if (nonMOPerson.profileImage) {
			cell.topImageView.hidden = NO;
			cell.topImageView.image = nonMOPerson.profileImage;
			cell.topImageView.contentMode = UIViewContentModeScaleAspectFit;
			cell.topPlaceholderLabel.hidden = YES;
			cell.topPlaceholderLabel.text = nil;
		} else {
			cell.topPlaceholderLabel.hidden = NO;
			cell.topPlaceholderLabel.text = [self initialsForPerson: nonMOPerson];
			cell.topImageView.image = nil;
			cell.topImageView.hidden = YES;
		}
	} else {
			//TODO  should this be a picture of self?  nobody was tagged, but there is a note
		cell.topImageView.image = nil;
		cell.topImageView.hidden = YES;
		cell.topPlaceholderLabel.text = nil;
		cell.topPlaceholderLabel.hidden = YES;

	}

	if ([peopleArray count] > 1) {
		NonMOPerson *nonMOPerson = [self.ceaselessContacts getNonMOPersonForCeaselessContact:[peopleArray lastObject]];
		if (nonMOPerson.profileImage) {
			cell.bottomImageView.hidden = NO;
			cell.bottomImageView.image = nonMOPerson.profileImage;
			cell.bottomImageView.contentMode = UIViewContentModeScaleAspectFit;
			cell.bottomPlaceholderLabel.hidden = YES;
			cell.bottomPlaceholderLabel.text = nil;
		} else {
			cell.bottomPlaceholderLabel.hidden = NO;
			cell.bottomPlaceholderLabel.text = [self initialsForPerson: nonMOPerson];
			cell.bottomImageView.image = nil;
			cell.bottomImageView.hidden = YES;
		}
	} else {
		cell.bottomImageView.image = nil;
		cell.bottomImageView.hidden = YES;
		cell.bottomPlaceholderLabel.text = nil;
		cell.bottomPlaceholderLabel.hidden = YES;
	}

	NSMutableSet *namesSet = [[NSMutableSet alloc] initWithCapacity: [note.peopleTagged count]];
	for (Person *personTagged in note.peopleTagged) {
		NonMOPerson *nonMOPerson = [self.ceaselessContacts getNonMOPersonForCeaselessContact:personTagged];
		NSString *personName = [NSString stringWithFormat: @"%@ %@", nonMOPerson.firstName, nonMOPerson.lastName];
		[namesSet addObject: personName];
	}
	NSString *allNamesString = [[namesSet allObjects] componentsJoinedByString:@", "];
	cell.peopleTagged.text = allNamesString;
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	dateFormatter.timeStyle = NSDateFormatterNoStyle;
	dateFormatter.dateStyle = NSDateFormatterShortStyle;
	NSDate *date = [note valueForKey:@"lastUpdatedDate"];

	cell.date.text = [dateFormatter stringFromDate:date];
	cell.text.text = [[note valueForKey:@"text"] description];
    cell.backgroundColor = [UIColor clearColor];
	
}

- (NSString*) initialsForPerson: (NonMOPerson *) nonMOPerson {
		// deal with cases of no lastName or firstName
		// We had an Akbar (null) name show up.
	if([nonMOPerson.firstName length] == 0) {
		nonMOPerson.firstName = @" "; // 1 character space for initials if needed
	}
	if([nonMOPerson.lastName length] == 0) {
		nonMOPerson.lastName = @" "; // 1 character space for initials if needed
	}

	NSString *firstInitial = [nonMOPerson.firstName substringToIndex: 1];
	NSString *lastInitial = [nonMOPerson.lastName substringToIndex: 1];
	return [NSString stringWithFormat: @"%@%@", firstInitial, lastInitial];
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
		// Return NO if you do not want the specified item to be editable.
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
		[context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];

		NSError *error = nil;
		if (![context save:&error]) {
				// Replace this implementation with code to handle the error appropriately.
				// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
			NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
			abort();
		}
	}
}

#pragma mark -
#pragma mark === UISearchBarDelegate ===
#pragma mark -

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope
{
	[self updateSearchResultsForSearchController:self.searchController];

}

#pragma mark -
#pragma mark === UISearchResultsUpdating ===
#pragma mark -

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
	NSString *searchString = searchController.searchBar.text;
	[self searchForText:searchString scope: searchController.searchBar.selectedScopeButtonIndex];
	[self.tableView reloadData];
}

- (void)searchForText:(NSString *)searchText scope:(PrayerJournalSearchScope)scopeOption
{
	if (self.managedObjectContext) {
		NSString *predicateFormat;

		if (scopeOption == searchScopeFriends) {
			predicateFormat = @"peopleTagged.@count > 0 AND text contains[cd] %@";
		} else {
			predicateFormat = @"peopleTagged.@count < 1 AND text contains[cd] %@";

		}

		NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, searchText];

		[self.searchFetchRequest setPredicate:predicate];

		NSError *error = nil;
		self.filteredList = [self.managedObjectContext executeFetchRequest:self.searchFetchRequest error:&error];
	}
}

#pragma mark - Fetched results controller
- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
		// In the simplest, most efficient, case, reload the table view.
 [self.tableView reloadData];
}
- (NSFetchedResultsController *)fetchedResultsController
{
	if (_fetchedResultsController != nil) {
		return _fetchedResultsController;
	}

	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		// Edit the entity name as appropriate.
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
	[fetchRequest setEntity:entity];

		// Set the batch size to a suitable number.
	[fetchRequest setFetchBatchSize:20];

		// Edit the sort key as appropriate.
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"lastUpdatedDate" ascending:NO];
	NSArray *sortDescriptors = @[sortDescriptor];

	[fetchRequest setSortDescriptors:sortDescriptors];

		// Edit the section name key path and cache name if appropriate.
		// nil for section name key path means "no sections".
	NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
	aFetchedResultsController.delegate = self;
	self.fetchedResultsController = aFetchedResultsController;

	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
			// Replace this implementation with code to handle the error appropriately.
			// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
	}

	return _fetchedResultsController;
}
- (NSFetchRequest *)searchFetchRequest
{
	if (_searchFetchRequest != nil)
  {
  return _searchFetchRequest;
  }

	_searchFetchRequest = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
	[_searchFetchRequest setEntity:entity];

	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"lastUpdatedDate" ascending:NO];
	NSArray *sortDescriptors = [NSArray arrayWithObjects:sortDescriptor, nil];
	[_searchFetchRequest setSortDescriptors:sortDescriptors];

	return _searchFetchRequest;
}
- (void) listAll {
	  // Test listing all tagData from the store
//  AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
//  NSManagedObjectContext *managedObjectContext = appDelegate.managedObjectContext;
  NSError * error = nil;

  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note"
											inManagedObjectContext:self.managedObjectContext];
  [fetchRequest setEntity:entity];


  NSArray *fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
  for (id managedObject in fetchedObjects) {

	  NSLog(@"create date: %@", [managedObject valueForKey: @"createDate"]);
	  NSLog(@"text: %@", [managedObject valueForKey: @"text"]);
	  NSLog(@"last update date: %@", [managedObject valueForKey: @"lastUpdatedDate"]);
  }
}

@end