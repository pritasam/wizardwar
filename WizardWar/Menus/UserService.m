//
//  UserFriendService.m
//  WizardWar
//
//  Created by Sean Hess on 6/21/13.
//  Copyright (c) 2013 The LAB. All rights reserved.
//

#import "UserService.h"
#import <Firebase/Firebase.h>
#import "IdService.h"
#import <CoreData/CoreData.h>
#import "ObjectStore.h"

@interface UserService ()
@property (nonatomic, strong) Firebase * node;
@property (nonatomic, strong) NSString * deviceToken;
@property (nonatomic, strong) NSString * entityName;
@end

@implementation UserService

+ (UserService *)shared {
    static UserService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UserService alloc] init];
    });
    return instance;
}

- (void)connect {
    self.node = [[Firebase alloc] initWithUrl:@"https://wizardwar.firebaseIO.com/users"];
    self.entityName = @"User";
    
    __weak UserService * wself = self;

    [self.node observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
        [wself onAdded:snapshot];
    }];
    
    [self.node observeEventType:FEventTypeChildRemoved withBlock:^(FDataSnapshot *snapshot) {
        [wself onRemoved:snapshot];
    }];
}

- (void)saveCurrentUser {
    // Save to firebase
    User * user = self.currentUser;
    if (!user) return;
    Firebase * child = [self.node childByAppendingPath:user.userId];
    [child setValue:user.toObject];
}

-(void)onAdded:(FDataSnapshot *)snapshot {
    NSString * userId = snapshot.name;
    User * user = [self userWithId:userId create:YES];
    [user setValuesForKeysWithDictionary:snapshot.value];
}

-(void)onRemoved:(FDataSnapshot*)snapshot {
    NSString * userId = snapshot.name;
    User * user = [self userWithId:userId];
    if (user)
        [ObjectStore.shared.context deleteObject:user];
}

- (User*)currentUser {
    if (!_currentUser) {
        User * user = [self userWithId:self.userId create:YES];
        self.currentUser = user;
    }
        
    return _currentUser;
}

- (Wizard*)currentWizard {
    // TODO, actually save this information, yo?
    // NSUserDefaults ftw
    Wizard * wizard = [Wizard new];
    wizard.name = self.currentUser.name;
    if (!wizard.name) wizard.name = [NSString stringWithFormat:@"Guest%@", [IdService randomId:4]];
    wizard.wizardType = WIZARD_TYPE_ONE;
    return wizard;
}

- (BOOL)isAuthenticated {
    return self.currentUser.name != nil;
}

- (NSString*)userId {
    return [UIDevice currentDevice].identifierForVendor.UUIDString;
}



# pragma mark - Users

- (User*)userWithId:(NSString*)userId {
    return [self userWithId:userId create:NO];
}

- (User*)userWithId:(NSString*)userId create:(BOOL)create {
    NSFetchRequest * request = [self requestAllUsers];
    request.predicate = [self predicateIsUser:userId];
    User * user = [ObjectStore.shared requestLastObject:request];
    if (!user) {
        user = [ObjectStore.shared insertNewObjectForEntityForName:self.entityName];
        user.userId = userId;
    }
    return user;
}

# pragma mark - Core Data

- (NSPredicate*)predicateIsUser:(NSString*)userId {
    return [NSPredicate predicateWithFormat:@"userId = %@", userId];
}

- (NSFetchRequest*)requestAllUsers {
    // valid users include:
    NSFetchRequest * request = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    request.predicate = [NSPredicate predicateWithFormat:@"name != nil"]; // AND deviceToken != nil"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:NO]];
    return request;
}

- (NSFetchRequest*)requestAllUsersButMe {
    NSFetchRequest * request = [self requestAllUsers];
    NSPredicate * notMe = [NSCompoundPredicate notPredicateWithSubpredicate:[self predicateIsUser:self.currentUser.userId]];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[notMe, request.predicate]];
    return request;
}

- (NSFetchRequest*)requestFriends {
    NSFetchRequest * request = [self requestAllUsersButMe];
    NSPredicate * isFriend = [NSPredicate predicateWithFormat:@"friendPoints > 0"];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[isFriend, request.predicate]];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"friendPoints" ascending:NO]];
    return request;
}

- (NSFetchRequest*)requestOnline {
    NSFetchRequest * request = [self requestAllUsersButMe];
    NSPredicate * isOnline = [NSPredicate predicateWithFormat:@"isOnline = YES"];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[isOnline, request.predicate]];
    return request;
}




@end
