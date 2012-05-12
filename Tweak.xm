#import <AddressBook/AddressBook.h>
#import "OBOContacts.h"

/* TODO:
2. (Huge) animation fix when there's time
*/

static id g_membersViewController = nil;

%hook ABMembersViewController
- (id)initWithModel:(id)arg1 {
	if ((self = %orig))
		g_membersViewController = self;
		
	return self;
}

- (void)viewDidLoad {
	%orig;
	UINavigationItem *navItem = [self navigationItem];
	
	UIBarButtonItem *item = [[[UIBarButtonItem alloc] initWithTitle:@"Edit" style:UIBarButtonItemStyleBordered target:self action:@selector(startEditing:)] autorelease];
	//[navItem setLeftBarButtonItem:[navItem rightBarButtonItem]];
	[navItem setLeftBarButtonItem:item];
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
	ABModel *model = [self model];
	NSInteger globalRow = [[tableView _rowData] globalRowForRowAtIndexPath:indexPath];
	ABRecordRef person = [model displayedMemberAtIndex:globalRow];
	ABAddressBookRef ab = [model addressBook];
	
	ABAddressBookRemoveRecord(ab, person, NULL);
	ABAddressBookSave(ab, NULL);
	
	[g_membersViewController personWasDeleted];
}
%end