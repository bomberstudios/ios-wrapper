//
//  ReadmillAPITests.m
//  ReadmillAPITests
//
//  Created by Martin Hwasser on 4/16/11.
//  Copyright 2011 Readmill. All rights reserved.
//

#import "ReadmillAPIReadingTests.h"
#import "OCMock.h"
#import "NSDateFormatter+ReadmillAdditions.h"
#import "NSString+ReadmillAdditions.h"
#import "ReadmillAPIWrapper+Internal.h"

/* Reading JSON v2

{
    "reading": {
        "id": 47783,
        "state": "finished",
        "private": false,
        "recommended": false,
        "closing_remark": "A closing remark.",
        "started_at": "2012-02-20T20:47:02Z",
        "touched_at": "2012-07-18T20:10:24Z",
        "ended_at": "2012-04-05T15:34:01Z",
        "duration": 31150,
        "progress": 1,
        "estimated_time_left": 0,
        "average_period_time": 1415,
        "book": {
            "id": 2855,
            "title": "Steve Jobs",
            "author": "Walter Isaacson",
            "permalink": "steve-jobs",
            "permalink_url": "http://stage-readmill.com/books/steve-jobs",
            "cover_url": "https://readmill-staging-assets.s3.amazonaws.com/covers/530281128f9cc98c346b6af29fa29483-medium.png?1344523475"
        },
        "user": {
            "id": 49,
            "username": "martinhwasser",
            "firstname": "Martin",
            "fullname": "Martin Hwasser",
            "avatar_url": "http://s3-eu-west-1.amazonaws.com/readmill-staging-assets/assets/default-avatar-medium-7db8a5328c515cad97a0800d6ac23419.png",
            "followers_count": 83,
            "followings_count": 104,
            "permalink_url": "http://stage-readmill.com/martinhwasser"
        },
        "permalink_url": "http://stage-readmill.com/martinhwasser/reads/steve-jobs",
        "comments_count": 3,
        "highlights_count": 33
    },
    "status": 200
}
*/

@implementation ReadmillAPIReadingTests 

- (void)setUp
{
    [super setUp];
    
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"reading47783"
                                                                      ofType:@"json"];
    
    NSData *data = [NSData dataWithContentsOfFile:path];    
    self.readingDictionary = [[data objectFromJSONData] retain];
}

- (void)tearDown
{
    // Tear-down code here.
    [_readingDictionary release];
    [super tearDown];
}

- (void)testCreateReading
{        
    ReadmillReading *reading = [[[ReadmillReading alloc] initWithAPIDictionary:self.readingDictionary
                                                                    apiWrapper:nil] autorelease];
    
    STAssertTrue([reading readingId] == 47783, @"ReadingId is wrong: %d", [reading readingId]);
    STAssertTrue([reading state] == ReadingStateFinished, @"State is wrong: %d", [reading state]);
    STAssertTrue([reading isPrivate] == NO, @"IsPrivate is wrong: %d", [reading isPrivate]);
    STAssertTrue([reading isRecommended] == NO, @"Recommended is wrong: %d", [reading isRecommended]);
    STAssertTrue([[reading closingRemark] isEqualToString:@"A closing remark."], @"closingRemark is wrong: %@", [reading closingRemark]);
    STAssertTrue([reading timeSpent] == 31150, @"timeSpent == %d", [reading timeSpent]);
    STAssertTrue([reading estimatedTimeLeft] == 0, @"timeLeft == %d", [reading estimatedTimeLeft]);
    NSDateFormatter *dateFormatter = [NSDateFormatter readmillDateFormatter];
    NSDate *date = [dateFormatter dateFromString:@"2012-02-20T20:47:02Z"];
    STAssertTrue([[reading dateStarted] isEqualToDate:date], @"dateStarted is wrong: %d", [reading dateStarted]);
//    STAssertTrue([reading isRecommended] == NO, @"Recommended is wrong: %d", [reading isRecommended]);
//    STAssertTrue([reading isRecommended] == NO, @"Recommended is wrong: %d", [reading isRecommended]);
}

- (void)testUserFromReading
{
    ReadmillReading *reading = [[[ReadmillReading alloc] initWithAPIDictionary:self.readingDictionary
                                                                    apiWrapper:nil] autorelease];
    
    ReadmillUser *user = [reading user];
    NSLog(@"user: %@", user);
    STAssertNotNil(user, @"User is nil!");
    STAssertTrue([user userId] == 49, @"User id wrong: %d", [user userId]);
    STAssertTrue([[user userName] isEqualToString:@"martinhwasser"], @"Wrong userName");
    STAssertTrue([[user firstName] isEqualToString:@"Martin"], @"Wrong firstName");
    STAssertTrue([[user fullName] isEqualToString:@"Martin Hwasser"], @"User name wrong: %@.", [user fullName]);
    STAssertNotNil([user avatarURL], @"Avatar url is nil");
    STAssertTrue([user followerCount] == 83, @"Follower count is wrong");
    STAssertTrue([user followingCount] == 104, @"Following count is wrong");
    STAssertNotNil([user permalinkURL], @"permalink is nil");
}

- (void)testPostReading
{
    ReadmillAPIConfiguration *apiConf = [ReadmillAPIConfiguration configurationForStagingWithClientID:@"a"
                                                                                         clientSecret:@"b"
                                                                                          redirectURL:nil];
    ReadmillAPIWrapper *wrapper = [[ReadmillAPIWrapper alloc] initWithAPIConfiguration:apiConf];
    id mockWrapper = [OCMockObject partialMockForObject:wrapper];
    
    NSString *readingState = @"reading";
    BOOL isPrivate = NO;
    ReadmillBookId bookId = 4711;
    NSArray *connections = @[@4712, @4713];

    void (^theBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        // Get the input parameters
        NSDictionary *allParameters;
        [invocation getArgument:&allParameters atIndex:3];
        
        NSDictionary *readingParameters = [allParameters valueForKey:kReadmillAPIReadingKey];
        
        // Check the count (since we're doing some other stuff like making it a dictionary)
        NSArray *postToParameters = [readingParameters valueForKey:kReadmillAPIReadingPostToKey];
        STAssertTrue([postToParameters count] == [connections count], @"Connection count is wrong: %d", [postToParameters count]);
    };
    
    // Inject our block
    [[[mockWrapper expect] andDo:theBlock] sendPostRequestToEndpoint:OCMOCK_ANY
                                                      withParameters:OCMOCK_ANY
                                                   completionHandler:OCMOCK_ANY];    
    
    
    [mockWrapper findOrCreateReadingWithBookId:bookId
                                         state:readingState
                                     isPrivate:isPrivate
                                   connections:connections
                             completionHandler:OCMOCK_ANY];
    [mockWrapper verify];
}

- (void)testUpdateReading
{
    id mockWrapper = [OCMockObject mockForClass:[ReadmillAPIWrapper class]];
    ReadmillReading *reading = [[[ReadmillReading alloc] initWithAPIDictionary:self.readingDictionary
                                                                    apiWrapper:mockWrapper] autorelease];

    [[mockWrapper expect] updateReadingWithId:[reading readingId]
                                    withState:ReadmillReadingStateFinishedKey
                                    isPrivate:[reading isPrivate]
                                closingRemark:[reading closingRemark] 
                            completionHandler:OCMOCK_ANY];
    
    [reading updateState:ReadingStateFinished delegate:nil];
    [mockWrapper verify];
}

- (void)testSessionIdentifierUpdates
{
    id mockWrapper = [OCMockObject niceMockForClass:[ReadmillAPIWrapper class]];
    ReadmillReading *reading = [[[ReadmillReading alloc] initWithAPIDictionary:self.readingDictionary
                                                                    apiWrapper:mockWrapper] autorelease];
    
    ReadmillReadingSession *readingSession = [reading createReadingSession];
    id mockReadingSession = [OCMockObject partialMockForObject:readingSession];
    NSString *sessionIdentifier = [readingSession sessionIdentifier];

    [[[mockReadingSession expect] andReturnValue:[NSNumber numberWithBool:NO]] isReadingSessionIdentifierValid];
    NSString *newSessionIdentifier = [mockReadingSession sessionIdentifier];
    
    STAssertTrue(![sessionIdentifier isEqualToString:newSessionIdentifier], @"Not equal session identifiers: %@, %@", sessionIdentifier, newSessionIdentifier);
    [mockReadingSession verify];
    
    // Test that it does not update if it's valid
    [[[mockReadingSession expect] andReturnValue:[NSNumber numberWithBool:YES]] isReadingSessionIdentifierValid];
    NSString *sameSessionIdentifier = [mockReadingSession sessionIdentifier];
    
    STAssertTrue([newSessionIdentifier isEqualToString:sameSessionIdentifier], @"Equal session identifiers: %@, %@", sessionIdentifier, newSessionIdentifier);
    [mockReadingSession verify];
}

@end
