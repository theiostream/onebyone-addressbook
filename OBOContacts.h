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

@interface ABMembersDataSource : NSObject <UITableViewDataSource, UIActionSheetDelegate>
- (ABModel *)model;
- (void)deleteContact;
@end

@interface ABMembersController : NSObject
- (UITableView *)tableView;
@end

@interface ABMembersViewController : UIViewController
- (id)initWithModel:(ABModel *)model;
- (ABMembersController *)membersController;
- (void)personWasDeleted;
- (void)updateEditButton;
@end

@interface ABMemberCell : UITableViewCell
- (void)setNamePieces:(NSArray *)pieces;

- (NSArray *)namePieces;
- (NSString *)namePieceForIndex:(NSUInteger)index;
- (void)setNamePiece:(NSUInteger)index toName:(NSString *)name;
- (void)adaptToEditing;
@end