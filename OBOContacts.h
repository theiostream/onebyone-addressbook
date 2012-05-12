@interface UITableViewRowData : NSObject
- (NSInteger)globalRowForRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface UITableView (OBOContacts)
- (UITableViewRowData *)_rowData;
@end

@interface ABModel : NSObject
- (ABRecordRef)displayedMemberAtIndex:(NSInteger)index;
- (ABAddressBookRef)addressBook;
@end

@interface ABMembersDataSource : NSObject <UITableViewDataSource>
- (ABModel *)model;
@end

@interface ABMembersController : NSObject
- (UITableView *)tableView;
@end

@interface ABMembersViewController : UIViewController
- (id)initWithModel:(ABModel *)model;
- (ABMembersController *)membersController;
- (void)personWasDeleted;
@end

@interface ABMemberCell : UITableViewCell
- (void)refresh;
- (void)setNamePieces:(NSArray *)pieces;
@end