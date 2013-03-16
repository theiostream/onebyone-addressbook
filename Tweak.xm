#import <AddressBook/AddressBook.h>
#import "OBOContacts.h"

/* TODO:
2. (Huge) animation fix when there's time
-- Draw rect instead of \t\t\t
-- Find a way to refresh the tableview more nicely
-- When we tap the Delete red stripe and cancel, shit happens.
*/

// From IconSupport; I am on a BIG hurry sorry world.
@interface UIDevice (OBOCPad)
- (BOOL)isWildcat;
@end
#define isiPad() ([UIDevice instancesRespondToSelector:@selector(isWildcat)] && [[UIDevice currentDevice] isWildcat])

#ifndef kCFCoreFoundationVersionNumber_iOS_6_0
#define kCFCoreFoundationVersionNumber_iOS_6_0 793.00
#endif
#define isiOS6() (kCFCoreFoundationVersionNumber>=kCFCoreFoundationVersionNumber_iOS_6_0)

static NSDictionary *contactsPrefs = nil;
static id g_membersViewController = nil;
static NSInteger g_globalRow = -1;
static BOOL g_isEditing = NO;

/* **********
*********** */

static void OBOContactsUpdatePrefs() {
	NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/am.theiostre.obo_contacts.plist"];
	if (!plist) return;

	contactsPrefs = [plist retain];
}

static void OBOContactsReloadPrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	OBOContactsUpdatePrefs();
}

static BOOL OBOCGetBoolPref(NSString *key, BOOL def) {
	if (!contactsPrefs) return def;
	
	NSNumber *v = [contactsPrefs objectForKey:key];
	return v ? [v boolValue] : def;
}

/* **********
*********** */

%hook ABMemberCell
%new(@@:)
- (NSArray *)namePieces {
	NSArray *_np = MSHookIvar<NSArray *>(self, "_namePieces");
	return _np;
}	

%new(@@:i)
- (NSString *)namePieceForIndex:(NSUInteger)index {
	NSArray *np = [self namePieces];
	return [np objectAtIndex:index];
}

%new(v@:i@)
- (void)setNamePiece:(NSUInteger)index toName:(NSString *)name {
	NSMutableArray *_np = [NSMutableArray arrayWithArray:[self namePieces]];
	
	[_np replaceObjectAtIndex:index withObject:name];
	[self setNamePieces:_np];
	
	[self setNeedsDisplay];
}

%new(v@:)
- (void)adaptToEditing {
	NSString *fn = [self namePieceForIndex:0];
	NSString *firstName = (g_isEditing ?
		[@"\t\t\t\t\t\t" stringByAppendingString:fn] :
		[fn stringByReplacingOccurrencesOfString:@"\t" withString:@""]);
	
	[self setNamePiece:0 toName:firstName];
}
%end

%hook ABMembersViewController
- (id)initWithModel:(id)arg1 {
	if ((self = %orig))
		g_membersViewController = self;
		
	return self;
}

- (void)viewWillAppear:(BOOL)animated {
	%orig;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateEditButton) name:UIApplicationWillEnterForegroundNotification object:nil];
	
	[self updateEditButton];
}

- (void)viewWillDisappear:(BOOL)animated {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	%orig;
}

%new(v@:)
- (void)updateEditButton {
	UINavigationItem *navItem = [self navigationItem];
	
	if (OBOCGetBoolPref(@"OBOCEnabled", YES) && OBOCGetBoolPref(@"OBOCEditButton", YES)) {
		UIBarButtonItem *item = [[[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStyleBordered target:self action:@selector(startEditing:)] autorelease];
		[navItem setLeftBarButtonItem:item];
	}
	
	else {
		NSString *buttonTitle = [[navItem leftBarButtonItem] title];
		if ([buttonTitle isEqualToString:@"Edit"] || [buttonTitle isEqualToString:@"Done"]) {
			[[[self membersController] tableView] setEditing:NO];
			[navItem setLeftBarButtonItem:nil];
		}
	}
}

%new(v@:@)
- (void)startEditing:(UIBarButtonItem *)item {
	UITableView *tableView = [[self membersController] tableView];
	BOOL isEditing = ![tableView isEditing];
	
	[tableView setEditing:isEditing animated:YES];
	
	[item setTitle:(isEditing ? @"Done" : @"Edit")];
	[item setStyle:(isEditing ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered)];
	
	g_isEditing = isEditing;
	
	NSArray *visibleCells = [tableView visibleCells];
	for (ABMemberCell *cell in visibleCells)
		[cell adaptToEditing];
}
%end

%hook ABMembersDataSource
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	id orig = %orig;
	if (g_isEditing) {
		[orig adaptToEditing];
	}
		
	return orig;
}

%new(c@:@@)
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return OBOCGetBoolPref(@"OBOCEnabled", YES);
}

%new(v@:@i@)
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		g_globalRow = [[tableView _rowData] globalRowForRowAtIndexPath:indexPath];
		if (isiOS6() && !isiPad() && [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.mobilephone"])
			g_globalRow--;
		
		if (OBOCGetBoolPref(@"OBOCAlertView", NO)) {
			UIActionSheet *confirm = [[[UIActionSheet alloc] initWithTitle:@"Delete Contact?" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete" otherButtonTitles:nil] autorelease];
			[confirm setTag:1234];
			[confirm showInView:tableView];
			
			return;
		}
		
		[self deleteContact];
	}
}

%new(v@:@i)
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if ([actionSheet tag] == 1234) {
		if (buttonIndex == [actionSheet destructiveButtonIndex]) {
			[self deleteContact];
		}
	}
}

%new(v@:)
- (void)deleteContact {
	ABModel *model = [self model];
	ABAddressBookRef ab = [model addressBook];
		
	ABRecordRef person = [model displayedMemberAtIndex:g_globalRow];
	
	ABAddressBookRemoveRecord(ab, person, NULL);
	ABAddressBookSave(ab, NULL);
	
	[g_membersViewController personWasDeleted];
}
%end

/* **********
*********** */

%ctor {
	NSAutoreleasePool *p = [NSAutoreleasePool new];
	%init;
	
	OBOContactsUpdatePrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
									NULL,
									&OBOContactsReloadPrefs,
									CFSTR("am.theiostre.obo_contacts.reload"),
									NULL,
									0);
	
	[p drain];
}