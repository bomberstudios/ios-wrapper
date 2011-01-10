//
//  ReadmillAPI.h
//  Readmill Framework
//
//  Created by Work on 10/01/2011.
//  Copyright 2011 KennettNet Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NSUInteger ReadmillBookId;
typedef NSUInteger ReadmillReadId;
typedef NSUInteger ReadmillUserId;
typedef NSUInteger ReadmillPingProgress; // Integer, 1-100 (%)
typedef NSUInteger ReadmillPingDuration; // Integer, seconds

typedef enum {
    
    kReadStateInteresting = 1,
    kReadStateReading = 2,
    kReadStateFinished = 3,
    kReadStateAbandoned = 4
    
} ReadmillReadState;

@interface ReadmillAPI : NSObject {
@private
    
    NSString *oAuthSecret;
    NSString *oAuthToken;
    
}

@property (readonly, copy) NSString *oAuthSecret;
@property (readonly, copy) NSString *oAuthToken;


// Books

-(NSArray *)allBooks:(NSError **)error;
-(NSArray *)booksMatchingTitle:(NSString *)searchString error:(NSError **)error;
-(NSArray *)booksMatchingISBN:(NSString *)isbn error:(NSError **)error;
-(NSDictionary *)addBookWithTitle:(NSString* )bookTitle author:(NSString *)bookAuthor isbn:(NSString *)bookIsbn error:(NSError **)error;

// Reads

-(NSDictionary *)createReadWithBookId:(ReadmillBookId)bookId state:(ReadmillReadState)readState applicationId:(NSString *)applicationId private:(BOOL)isPrivate error:(NSError **)error;
-(NSDictionary *)updateReadWithId:(ReadmillReadId)readId withState:(ReadmillReadState)readState applicationId:(NSString *)applicationId private:(BOOL)isPrivate closingRemark:(NSString *)remark error:(NSError **)error;
-(NSArray *)publicReadsForUserWithId:(ReadmillUserId)userId error:(NSError **)error;
-(NSArray *)publicReadsForUserWithName:(NSString *)userName error:(NSError **)error;

//Pings     

-(NSDictionary *)pingReadWithId:(ReadmillReadId)readId withProgress:(ReadmillPingProgress)progress sessionIdentifier:(NSString *)sessionId duration:(ReadmillPingDuration)duration occuranceTime:(NSDate *)occuranceTime error:(NSError **)error;

// Users

-(NSDictionary *)userWithId:(ReadmillUserId)userId error:(NSError **)error;
-(NSDictionary *)userWithName:(NSString *)userName error:(NSError **)error;


@end
