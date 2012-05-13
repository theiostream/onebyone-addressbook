#import <AddressBook/AddressBook.h>
#import "OBOContacts.h"

/* TODO:
2. (Huge) animation fix when there's time
*/

static NSDictionary *contactsPrefs = nil;
static id g_membersViewController = nil;
static NSInteger g_globalRow = -1;

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

%hook ABMembersViewController
- (id)initWithModel:(id)arg1 {
	if ((self = %orig))
		g_membersViewController = self;
		
	return self;
}

- (void)viewDidLoad {
	%log;
	%orig;
	
	if (OBOCGetBoolPref(@"OBOCEditButton", YES)) {
		UIBarButtonItem *item = [[[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStyleBordered target:self action:@selector(startEditing:)] autorelease];
		[[self navigationItem] setLeftBarButtonItem:item];
	}
}

%new
- (void)startEditing:(UIBarButtonItem *)item {
	UITableView *tableView = [[self membersController] tableView];
	BOOL isEditing = [tableView isEditing];
	
	[tableView setEditing:!isEditing animated:YES];
	
	[item setTitle:(isEditing ? @"Edit" : @"Done")];
	[item setStyle:(isEditing ? UIBarButtonItemStyleBordered : UIBarButtonItemStyleDone)];
	
	NSArray *visibleCells = [tableView visibleCells];
	for (ABMemberCell *cell in visibleCells)
		[cell refresh];
}
%end

%hook ABMemberCell
%new
- (void)refresh {
	NSArray *np = MSHookIvar<NSArray *>(self, "_namePieces");
	NSString *fn = [np objectAtIndex:0];
	
	// FIXME: idk, just fixme.
	NSString *firstName = ([self isEditing] ?
		[@"\t\t\t\t\t\t" stringByAppendingString:fn] :
		[fn stringByReplacingOccurrencesOfString:@"\t" withString:@""]);
	
	NSMutableArray *_np = [NSMutableArray arrayWithArray:np];
	[_np replaceObjectAtIndex:0 withObject:firstName];
	[self setNamePieces:_np];
	
	[self setNeedsDisplay];
}
%end

%hook ABMembersDataSource
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	id orig = %orig;
	if ([tableView isEditing])
		[orig refresh];
		
	return orig;
}

%new
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	g_globalRow = [[tableView _rowData] globalRowForRowAtIndexPath:indexPath];
	
	if (OBOCGetBoolPref(@"OBOCAlertView", NO)) {
		UIActionSheet *confirm = [[[UIActionSheet alloc] initWithTitle:@"Delete Contact" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete" otherButtonTitles:nil] autorelease];
		[confirm setTag:1234];
		[confirm showInView:tableView];
		
		return;
	}
	
	[self deleteContact];
}

%new
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if ([actionSheet tag] == 1234) {
		if (buttonIndex == [actionSheet destructiveButtonIndex]) {
			[self deleteContact];
		}
	}
}

%new
- (void)deleteContact {
	ABModel *model = [self model];
	ABAddressBookRef ab = [model addressBook];
	ABRecordRef person = [model displayedMemberAtIndex:g_globalRow];
	
	ABAddressBookRemoveRecord(ab, person, NULL);
	ABAddressBookSave(ab, NULL);
	
	[g_membersViewController personWasDeleted];
}
%end

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