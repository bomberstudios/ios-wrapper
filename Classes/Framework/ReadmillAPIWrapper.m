/*
 Copyright (c) 2011 Readmill LTD
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "ReadmillAPIWrapper.h"
#import "NSString+ReadmillAdditions.h"
#import "NSURL+ReadmillURLParameters.h"
#import "NSError+ReadmillAdditions.h"
#import "NSDictionary+ReadmillAdditions.h"
#import "NSDate+ReadmillAdditions.h"
#import "ReadmillAPIWrapper+Internal.h"
#import "ReadmillRequestOperation.h"

@interface ReadmillAPIWrapper ()

@property (readwrite, copy) NSString *refreshToken;
@property (readwrite, copy) NSString *accessToken;
@property (readwrite, copy) NSString *authorizedRedirectURL;
@property (readwrite, copy) NSDate *accessTokenExpiryDate;
@property (nonatomic, readwrite, retain) NSOperationQueue *queue;
@property (nonatomic, readwrite, retain) ReadmillAPIConfiguration *apiConfiguration;

@end

@implementation ReadmillAPIWrapper

- (id)init
{
    if ((self = [super init])) {
        // Initialization code here.
        queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
    }
    return self;
}

- (id)initWithAPIConfiguration:(ReadmillAPIConfiguration *)configuration
{
    self = [self init];
    if (self) {
        NSAssert(configuration != nil, @"API Configuration is nil");
        [self setApiConfiguration:configuration];
    }
    return self;
}

- (id)initWithPropertyListRepresentation:(NSDictionary *)plist
{
    if ((self = [self init])) {
        [self setAuthorizedRedirectURL:[plist valueForKey:@"authorizedRedirectURL"]];
		[self setAccessToken:[plist valueForKey:@"accessToken"]];
        [self setAccessTokenExpiryDate:[plist valueForKey:@"accessTokenExpiryDate"]];
        [self setApiConfiguration:[NSKeyedUnarchiver unarchiveObjectWithData:[plist valueForKey:@"apiConfiguration"]]];
    }
    return self;
}

- (NSDictionary *)propertyListRepresentation
{
    NSMutableDictionary *plist = [NSMutableDictionary dictionary];
    [plist setValue:[self accessToken]
              forKey:@"accessToken"];
    [plist setValue:[self authorizedRedirectURL]
              forKey:@"authorizedRedirectURL"];
    [plist setValue:[NSKeyedArchiver archivedDataWithRootObject:[self apiConfiguration]]
              forKey:@"apiConfiguration"];
    [plist setValue:[self accessTokenExpiryDate] forKey:@"accessTokenExpiryDate"];
    
    return plist;
}

@synthesize refreshToken;
@synthesize accessToken;
@synthesize authorizedRedirectURL;
@synthesize accessTokenExpiryDate;
@synthesize apiConfiguration;
@synthesize queue;

- (void)dealloc
{
    [self setAccessToken:nil];
    [self setAuthorizedRedirectURL:nil];
    [self setAccessTokenExpiryDate:nil];
    [self setApiConfiguration:nil];
    [self setQueue:nil];
    [super dealloc];
}

#pragma mark -
#pragma mark API endpoints

- (NSString *)apiEndPoint
{
    return [[self.apiConfiguration apiBaseURL] absoluteString];
}

- (NSString *)booksEndpoint
{
    return @"books";
}

- (NSString *)readingsEndpoint
{
    return @"readings";
}

- (NSString *)usersEndpoint
{
    return @"users";
}

- (NSString *)highlightsEndpoint
{
    return @"highlights";
}

- (NSString *)closingRemarksEndpoint
{
    return @"closing_remarks";
}

- (NSString *)commentsEndpoint
{
    return @"comments";
}

- (NSString *)likesEndpoint
{
    return @"likes";
}

- (NSString *)libraryEndPoint
{
    return @"me/library";
}


#pragma mark -
#pragma mark OAuth

- (void)authorizeWithAuthorizationCode:(NSString *)authCode
                       fromRedirectURL:(NSString *)redirectURLString
                     completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    [self setAuthorizedRedirectURL:redirectURLString];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                [[self apiConfiguration] clientID], kReadmillAPIClientIdKey,
                                [[self apiConfiguration] clientSecret], kReadmillAPIClientSecretKey,
                                authCode, @"code",
                                redirectURLString, @"redirect_uri",
                                @"authorization_code", @"grant_type", nil];

    [self authorizeWithParameters:parameters completionHandler:completionHandler];
}

- (void)authorizeWithParameters:(NSDictionary *)parameters
              completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[[self apiConfiguration] accessTokenURL]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                       timeoutInterval:kTimeoutInterval];
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil]];

    [self startPreparedRequest:request completion:^(NSDictionary *response, NSError *error) {
        if (response != nil) {
            NSTimeInterval accessTokenTTL = [[response valueForKey:@"expires_in"] doubleValue];
            [self willChangeValueForKey:@"propertyListRepresentation"];
            [self setAccessTokenExpiryDate:[[NSDate date] dateByAddingTimeInterval:accessTokenTTL]];
            [self setAccessToken:[response valueForKey:@"access_token"]];
            [self didChangeValueForKey:@"propertyListRepresentation"];
        }
        completionHandler(response, error);
    }];
}

- (NSURL *)clientAuthorizationURLWithRedirectURLString:(NSString *)redirect
{
    NSString *baseURL = [[[self apiConfiguration] authURL] absoluteString];
    NSString *urlString = [NSString stringWithFormat:@"%@oauth/authorize?response_type=code&client_id=%@&scope=non-expiring",
                           baseURL,
                           [[self apiConfiguration] clientID]];
    
    if ([redirect length] > 0) {
        // Need to urlEncode the URL string
        urlString = [NSString stringWithFormat:@"%@&redirect_uri=%@", urlString, [redirect urlEncodedString]];
    }
    return [NSURL URLWithString:urlString];
}

#pragma mark -
#pragma mark API Methods

#pragma mark - Readings

- (ReadmillRequestOperation *)readingForUserWithId:(ReadmillUserId)userId
                                matchingBookWithId:(ReadmillBookId)bookId
                                 completionHandler:(ReadmillAPICompletionHandler)completion
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/readings/match",
                          [self usersEndpoint],
                          userId];

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [parameters setValue:@(bookId) forKey:@"book_id"];

    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:parameters
               shouldBeCalledUnauthorized:NO
                        completionHandler:completion];
}

- (ReadmillRequestOperation *)readingForUserWithId:(ReadmillUserId)userId
                                matchingIdentifier:(NSString *)identifier
                                             title:(NSString *)title
                                            author:(NSString *)author
                                 completionHandler:(ReadmillAPICompletionHandler)completion
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/readings/match",
                          [self usersEndpoint],
                          userId];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [parameters setValue:identifier forKey:kReadmillAPIBookIdentifierKey];
    [parameters setValue:title forKey:kReadmillAPIBookTitleKey];
    [parameters setValue:author forKey:kReadmillAPIBookAuthorKey];
    
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:parameters
               shouldBeCalledUnauthorized:NO
                        completionHandler:completion];
    
}

- (ReadmillRequestOperation *)findOrCreateReadingWithBookId:(ReadmillBookId)bookId
                                                      state:(NSString *)readingState
                                                  isPrivate:(BOOL)isPrivate
                                                connections:(NSArray *)connections
                                          completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *readingParameters = [NSMutableDictionary dictionary];
    
    [readingParameters setValue:readingState
                         forKey:kReadmillAPIReadingStateKey];
    [readingParameters setValue:isPrivate ? @"true" : @"false"
                         forKey:kReadmillAPIReadingPrivateKey];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:readingParameters
                                                                         forKey:kReadmillAPIReadingKey];
    
    if (connections != nil) {
        [readingParameters setValue:connections
                             forKey:kReadmillAPIReadingPostToKey];
    }
    
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/readings",
                          [self booksEndpoint],
                          bookId];
    
    return [self sendPostRequestToEndpoint:endpoint
                            withParameters:parameters
                         completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)findOrCreateReadingWithBookId:(ReadmillBookId)bookId
                                                      state:(NSString *)readingState
                                                  isPrivate:(BOOL)isPrivate
                                          completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self findOrCreateReadingWithBookId:bookId
                                         state:readingState
                                     isPrivate:isPrivate
                                   connections:nil
                             completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)updateReadingWithId:(ReadmillReadingId)readingId
                                        toPrivate:(BOOL)toPrivate
                                completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self updateReadingWithId:readingId
                           withState:nil
                           isPrivate:toPrivate
                       closingRemark:nil
                   completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)updateReadingWithId:(ReadmillReadingId)readingId
                                        withState:(NSString *)readingState
                                        isPrivate:(BOOL)isPrivate
                                    closingRemark:(NSString *)remark
                                completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *readingParameters = [[NSMutableDictionary alloc] init];
    
    [readingParameters setValue:readingState
                         forKey:kReadmillAPIReadingStateKey];
    [readingParameters setValue:@(isPrivate)
                         forKey:kReadmillAPIReadingPrivateKey];
    
    if ([remark length] > 0) {
        [readingParameters setValue:remark
                             forKey:kReadmillAPIReadingClosingRemarkKey];
    }
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:readingParameters
                                                           forKey:kReadmillAPIReadingKey];
    [readingParameters release];
    
    return [self updateReadingWithId:readingId
                          parameters:parameters
                   completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)updateReadingWithId:(ReadmillReadingId)readingId
                                            state:(NSString *)readingState
                                    closingRemark:(NSString *)closingRemark
                                      recommended:(BOOL)recommended
                                      connections:(NSArray *)connections
                                completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *readingParameters = [[NSMutableDictionary alloc] init];
    
    [readingParameters setValue:readingState
                         forKey:kReadmillAPIReadingStateKey];
    [readingParameters setValue:[NSNumber numberWithUnsignedInteger:recommended]
                         forKey:kReadmillAPIReadingRecommendedKey];

    if ([closingRemark length] > 0) {
        [readingParameters setValue:closingRemark
                             forKey:kReadmillAPIReadingClosingRemarkKey];
    }
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:readingParameters
                                                                         forKey:kReadmillAPIReadingKey];
    [readingParameters release];
    
    if (connections != nil) {
        [readingParameters setValue:connections
                             forKey:kReadmillAPIHighlightPostToKey];
    }
    
    return [self updateReadingWithId:readingId
                          parameters:parameters
                   completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)finishReadingWithId:(ReadmillReadingId)readingId
                                    closingRemark:(NSString *)closingRemark
                                      recommended:(BOOL)recommended
                                      connections:(NSArray *)connections
                                completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self updateReadingWithId:readingId
                               state:ReadmillReadingStateFinishedKey
                       closingRemark:closingRemark
                         recommended:recommended
                         connections:connections
                   completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)abandonReadingWithId:(ReadmillReadingId)readingId
                                     closingRemark:(NSString *)closingRemark
                                       connections:(NSArray *)connections
                                 completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self updateReadingWithId:readingId
                               state:ReadmillReadingStateAbandonedKey
                       closingRemark:closingRemark
                         recommended:NO
                         connections:connections
                   completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)updateReadingWithId:(ReadmillReadingId)readingId
                                       parameters:(NSDictionary *)parameters
                                completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d",
                          [self readingsEndpoint],
                          readingId];
    return [self sendPutRequestToEndpoint:endpoint
                           withParameters:parameters
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)publicReadingsForUserWithId:(ReadmillUserId)userId completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/readings",
                          [self usersEndpoint],
                          userId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:nil
               shouldBeCalledUnauthorized:YES
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)readingsForUserWithId:(ReadmillUserId)userId
                                         parameters:(NSDictionary *)parameters
                                  completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/readings",
                          [self usersEndpoint],
                          userId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:parameters
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)readingWithId:(ReadmillReadingId)readingId
                          completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d",
                          [self readingsEndpoint],
                          readingId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:nil
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)readingsForBookWithId:(ReadmillBookId)bookId
                                         parameters:(NSDictionary *)parameters
                                  completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/readings",
                          [self booksEndpoint],
                          bookId];
    
    NSString *filter = [parameters valueForKey:kReadmillAPIReadingFilterKey];
    NSString *order = [parameters valueForKey:kReadmillAPIReadingOrderKey];
    
    BOOL unauthorized = YES;
    if ([filter isEqualToString:kReadmillAPIReadingFilterFollowings] ||
        [order isEqualToString:kReadmillAPIReadingOrderFriendsFirst]) {
        unauthorized = NO;
    }
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:parameters
               shouldBeCalledUnauthorized:unauthorized
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)readingsForBookWithId:(ReadmillBookId)bookId
                                  completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self readingsForBookWithId:bookId
                            parameters:nil
                     completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)readingsFilteredByFriendsForBookWithId:(ReadmillBookId)bookId
                                                          parameters:(NSDictionary *)parameters
                                                   completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *finalParameters = [@{ kReadmillAPIReadingFilterKey : kReadmillAPIReadingFilterFollowings } mutableCopy];
    [finalParameters addEntriesFromDictionary:parameters];

    return [self readingsForBookWithId:bookId
                            parameters:finalParameters
                     completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)readingsOrderedByPopularForBookWithId:(ReadmillBookId)bookId
                                                         parameters:(NSDictionary *)parameters
                                                  completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *finalParameters = [@{ kReadmillAPIReadingOrderKey : kReadmillAPIReadingOrderPopular } mutableCopy];
    [finalParameters addEntriesFromDictionary:parameters];

    return [self readingsForBookWithId:bookId
                            parameters:finalParameters
                     completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)readingsOrderedByFriendsFirstForBookWithId:(ReadmillBookId)bookId
                                                              parameters:(NSDictionary *)parameters
                                                       completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *finalParameters = [@{ kReadmillAPIReadingOrderKey : kReadmillAPIReadingOrderFriendsFirst } mutableCopy];
    [finalParameters addEntriesFromDictionary:parameters];

    return [self readingsForBookWithId:bookId
                            parameters:finalParameters
                     completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)periodsForReadingWithId:(ReadmillReadingId)readingId
                                    completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/periods",
                          [self readingsEndpoint],
                          readingId];
    
    NSDictionary *parameters = @{ @"count" : @100 };
    
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:parameters
               shouldBeCalledUnauthorized:NO
                              cachePolicy:NSURLRequestReturnCacheDataElseLoad
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)positionForReadingWithId:(ReadmillReadingId)readingId
                                     completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/position",
                          [self readingsEndpoint],
                          readingId];
    
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:nil
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)updatePosition:(double)position
                            forReadingWithId:(ReadmillReadingId)readingId
                           completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/position",
                          [self readingsEndpoint],
                          readingId];
    
    NSDictionary *parameters = @{ kReadmillAPIReadingPositionKey :
                                @ { kReadmillAPIReadingPositionKey : @(position) }};
    return [self sendPutRequestToEndpoint:endpoint
                           withParameters:parameters
                        completionHandler:completionHandler];
}


#pragma mark -
#pragma mark - Book

- (ReadmillRequestOperation *)bookWithId:(ReadmillBookId)bookId completionHandler:(ReadmillAPICompletionHandler)completion
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d", [self booksEndpoint], bookId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:nil
               shouldBeCalledUnauthorized:YES
                        completionHandler:completion];
}

- (ReadmillRequestOperation *)bookMatchingTitle:(NSString *)title
                                         author:(NSString *)author
                              completionHandler:(ReadmillAPICompletionHandler)completion
{
    return [self bookMatchingIdentifier:nil
                                  title:title
                                 author:author
                      completionHandler:completion];
}

- (ReadmillRequestOperation *)bookMatchingIdentifier:(NSString *)identifier
                                   completionHandler:(ReadmillAPICompletionHandler)completion
{
    return [self bookMatchingIdentifier:identifier
                                  title:nil
                                 author:nil
                      completionHandler:completion];
}

- (ReadmillRequestOperation *)bookMatchingIdentifier:(NSString *)identifier
                                               title:(NSString *)title
                                              author:(NSString *)author
                                   completionHandler:(ReadmillAPICompletionHandler)completion
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [parameters setValue:identifier forKey:kReadmillAPIBookIdentifierKey];
    [parameters setValue:author forKey:kReadmillAPIBookAuthorKey];
    [parameters setValue:title forKey:kReadmillAPIBookTitleKey];
    
    return [self sendGetRequestToEndpoint:[NSString stringWithFormat:@"%@/match", [self booksEndpoint]]
                           withParameters:parameters
               shouldBeCalledUnauthorized:NO
                        completionHandler:completion];
}

- (ReadmillRequestOperation *)findOrCreateBookWithTitle:(NSString *)bookTitle
                                                 author:(NSString *)bookAuthor
                                             identifier:(NSString *)bookIdentifier
                                      completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *bookParameters = [[NSMutableDictionary alloc] init];
    
    if ([bookTitle length] > 0) {
        [bookParameters setValue:bookTitle
                          forKey:kReadmillAPIBookTitleKey];
    }
    
    if ([bookAuthor length] > 0) {
        [bookParameters setValue:bookAuthor
                          forKey:kReadmillAPIBookAuthorKey];
    }
    
    if ([bookIdentifier length] > 0) {
        [bookParameters setValue:bookIdentifier
                          forKey:kReadmillAPIBookIdentifierKey];
    }
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:bookParameters
                                                           forKey:kReadmillAPIBookKey];
    [bookParameters release];
    
    return [self sendPostRequestToEndpoint:[NSString stringWithFormat:@"%@", [self booksEndpoint]]
                            withParameters:parameters
                         completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)booksWithParameters:(NSDictionary *)parameters
                                completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self sendGetRequestToEndpoint:[NSString stringWithFormat:@"%@", [self booksEndpoint]]
                           withParameters:parameters
               shouldBeCalledUnauthorized:YES
                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)closingRemarksForBookWithId:(ReadmillBookId)bookId parameters:(NSDictionary *)parameters completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/closing_remarks", [self booksEndpoint], bookId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:parameters
               shouldBeCalledUnauthorized:YES
                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)searchBooksUsingQuery:(NSString *)query
                                         parameters:(NSDictionary *)parameters
                                  completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/search", [self booksEndpoint]];

    NSMutableDictionary *finalDictionary = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [finalDictionary setValue:query forKey:@"query"];

    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:finalDictionary
               shouldBeCalledUnauthorized:YES
                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        completionHandler:completionHandler];
}

- (NSURL *)coverURLForBookWithId:(ReadmillBookId)bookId
                            size:(NSString *)size
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/cover", [self booksEndpoint], bookId];
    NSDictionary *parameters = @{ kReadmillAPIBookCoverSizeKey : size,
                                  kReadmillAPIClientIdKey : self.apiConfiguration.clientID };
    return [self coverURLForBookWithId:bookId parameters:parameters];
}

- (NSURL *)coverURLForBookWithId:(ReadmillBookId)bookId
                      parameters:(NSDictionary *)parameters
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/cover?%@=%@", [self booksEndpoint], bookId, kReadmillAPIClientIdKey, [self.apiConfiguration clientID]];
    for (NSString *key in [parameters allKeys]) {
        endpoint = [endpoint stringByAppendingFormat:@"&%@=%@", key, parameters[key]];
    }
    return [NSURL URLWithString:endpoint relativeToURL:self.apiConfiguration.apiBaseURL];
}


//Pings
#pragma mark - Pings

- (ReadmillRequestOperation *)pingReadingWithId:(ReadmillReadingId)readingId
                                   withProgress:(ReadmillReadingProgress)progress
                              sessionIdentifier:(NSString *)sessionId
                                       duration:(ReadmillPingDuration)duration
                                 occurrenceTime:(NSDate *)occurrenceTime
                                       latitude:(CLLocationDegrees)latitude
                                      longitude:(CLLocationDegrees)longitude
                              completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *pingParameters = [[NSMutableDictionary alloc] init];
    
    [pingParameters setValue:[NSNumber numberWithFloat:progress]
                      forKey:kReadmillAPIPingProgressKey];
    [pingParameters setValue:[NSNumber numberWithUnsignedInteger:duration]
                      forKey:kReadmillAPIPingDurationKey];
    
    if ([sessionId length] > 0) {
        [pingParameters setValue:sessionId
                          forKey:kReadmillAPIPingIdentifierKey];
    }
    
    if (occurrenceTime == nil) {
        occurrenceTime = [NSDate date];
    }
    
    // 2011-01-06T11:47:14Z
    NSString *dateString = [occurrenceTime stringWithRFC3339Format];
    [pingParameters setValue:dateString
                      forKey:kReadmillAPIPingOccurredAtKey];
    
    if (!(longitude == 0.0 && latitude == 0.0)) {
        // Do not send gps values if lat/lng were not specified.
        [pingParameters setValue:[NSNumber numberWithDouble:latitude]
                          forKey:kReadmillAPIPingLatitudeKey];
        [pingParameters setValue:[NSNumber numberWithDouble:longitude]
                          forKey:kReadmillAPIPingLongitudeKey];
    }
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:pingParameters
                                                           forKey:kReadmillAPIPingKey];
    [pingParameters release];
    
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/%@",
                          [self readingsEndpoint],
                          readingId,
                          kReadmillAPIPingKey];
    
    return [self sendPostRequestToEndpoint:endpoint
                            withParameters:parameters
                         completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)pingReadingWithId:(ReadmillReadingId)readingId
                                   withProgress:(ReadmillReadingProgress)progress
                              sessionIdentifier:(NSString *)sessionId
                                       duration:(ReadmillPingDuration)duration
                                 occurrenceTime:(NSDate *)occurrenceTime
                              completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self pingReadingWithId:readingId
                      withProgress:progress
                 sessionIdentifier:sessionId
                          duration:duration
                    occurrenceTime:occurrenceTime
                          latitude:0.0
                         longitude:0.0
                 completionHandler:completionHandler];
}


#pragma mark -
#pragma mark - Highlights

- (ReadmillRequestOperation *)createHighlightForReadingWithId:(ReadmillReadingId)readingId
                                                   parameters:(NSDictionary *)parameters
                                            completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/highlights", [self readingsEndpoint], readingId];
    return [self sendPostRequestToEndpoint:endpoint
                            withParameters:parameters
                         completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)createHighlightForReadingWithId:(ReadmillReadingId)readingId
                                              highlightedText:(NSString *)highlightedText
                                                     locators:(NSDictionary *)locators
                                                     position:(ReadmillReadingProgress)position
                                                highlightedAt:(NSDate *)highlightedAt
                                                      comment:(NSString *)comment
                                                  connections:(NSArray *)connections
                                             isCopyRestricted:(BOOL)isCopyRestricted
                                            completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSAssert(0 < readingId, @"readingId: %d is invalid.", readingId);
    NSAssert(highlightedText != nil && [highlightedText length], @"Highlighted text can't be nil.");
    NSAssert(locators != nil && [locators count], @"Locators can't be nil.");
    
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary *highlightParameters = [[NSMutableDictionary alloc] init];
    [highlightParameters setValue:locators
                           forKey:kReadmillAPIHighlightLocatorsKey];
    [highlightParameters setValue:highlightedText
                           forKey:kReadmillAPIHighlightContentKey];
    [highlightParameters setValue:[NSNumber numberWithFloat:position]
                           forKey:kReadmillAPIHighlightPositionKey];
    [highlightParameters setValue:[NSNumber numberWithBool:isCopyRestricted]
                           forKey:@"copy_restricted"];
    
    if (comment != nil && 0 < [comment length]) {
        NSDictionary *commentContentDictionary = [NSDictionary dictionaryWithObject:comment
                                                                             forKey:kReadmillAPIHighlightContentKey];
        [parameters setValue:commentContentDictionary forKey:kReadmillAPIHighlightCommentKey];
    }
    
    if (connections != nil) {
        [highlightParameters setValue:connections
                               forKey:kReadmillAPIHighlightPostToKey];
    }
    
    if (!highlightedAt) {
        highlightedAt = [NSDate date];
    }
    // 2011-01-06T11:47:14Z
    [highlightParameters setValue:[highlightedAt stringWithRFC3339Format]
                           forKey:kReadmillAPIHighlightHighlightedAtKey];
    [parameters setObject:highlightParameters forKey:kReadmillAPIHighlightKey];
    [highlightParameters release];
    
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/highlights", [self readingsEndpoint], readingId];
    
    return [self sendPostRequestToEndpoint:endpoint
                            withParameters:[parameters autorelease]
                         completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)highlightsForReadingWithId:(ReadmillReadingId)readingId
                                       completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self highlightsForReadingWithId:readingId
                                      count:100
                                   fromDate:nil
                                     toDate:nil
                          completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)highlightsForReadingWithId:(ReadmillReadingId)readingId count:(NSUInteger)count fromDate:(NSDate *)fromDate toDate:(NSDate *)toDate completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:3];
    [parameters setValue:@(count) forKey:@"count"];
    [parameters setValue:@"highlighted_at" forKey:@"order"];
    [parameters setValue:[fromDate stringWithRFC3339Format] forKey:@"from"];
    [parameters setValue:[toDate stringWithRFC3339Format] forKey:@"to"];
    
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/highlights", [self readingsEndpoint], readingId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:parameters
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)highlightWithId:(ReadmillHighlightId)highlightId
                            completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d", [self highlightsEndpoint], highlightId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:nil
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)deleteHighlightWithId:(NSUInteger)highlightId
                                  completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d", [self highlightsEndpoint], highlightId];
    return [self sendDeleteRequestToEndpoint:endpoint
                              withParameters:nil
                           completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)highlightsForUserWithId:(ReadmillUserId)userId
                                                count:(NSUInteger)count
                                             fromDate:(NSDate *)fromDate
                                               toDate:(NSDate *)toDate
                                    completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setValue:[NSNumber numberWithUnsignedInteger:count] forKey:@"count"];
    [parameters setValue:fromDate forKey:@"from"];
    [parameters setValue:toDate forKey:@"to"];

    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/highlights", [self usersEndpoint], userId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:[parameters autorelease]
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

#pragma mark Closing remark

- (ReadmillRequestOperation *)closingRemarkWithId:(ReadmillClosingRemarkId)closingRemarkId
                                completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d", [self closingRemarksEndpoint], closingRemarkId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:nil
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

#pragma mark - Highlight comments

- (ReadmillRequestOperation *)createCommentForHighlightWithId:(ReadmillHighlightId)highlightId
                                comment:(NSString *)comment
                            commentedAt:(NSDate *)date
                      completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/comments", [self highlightsEndpoint], highlightId];
    
    NSDictionary *commentDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                       comment, kReadmillAPICommentContentKey,
                                       [date stringWithRFC3339Format], kReadmillAPICommentPostedAtKey, nil];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:commentDictionary
                                                           forKey:@"comment"];
    
    return [self sendPostRequestToEndpoint:endpoint
                            withParameters:parameters
                         completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)commentsForHighlightWithId:(ReadmillHighlightId)highlightId
                                       completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self commentsForHighlightWithId:highlightId
                                      count:100
                                   fromDate:nil
                                     toDate:nil
                          completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)commentsForHighlightWithId:(ReadmillHighlightId)highlightId
                                                   count:(NSUInteger)count
                                                fromDate:(NSDate *)fromDate
                                                  toDate:(NSDate *)toDate
                                       completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setValue:[NSNumber numberWithUnsignedInteger:count] forKey:@"count"];
    [parameters setValue:fromDate forKey:@"from"];
    [parameters setValue:toDate forKey:@"to"];
    
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/comments",
                          [self highlightsEndpoint],
                          highlightId];
    
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:[parameters autorelease]
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)createCommentForClosingRemarkWithId:(ReadmillClosingRemarkId)closingRemarkId
                                                          comment:(NSString *)comment
                                                      commentedAt:(NSDate *)date
                                                completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/comments", [self closingRemarksEndpoint], closingRemarkId];
    
    NSDictionary *commentDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                       comment, kReadmillAPICommentContentKey,
                                       [date stringWithRFC3339Format], kReadmillAPICommentPostedAtKey, nil];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:commentDictionary
                                                           forKey:@"comment"];
    
    return [self sendPostRequestToEndpoint:endpoint
                            withParameters:parameters
                         completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)commentsForClosingRemarkWithId:(ReadmillClosingRemarkId)closingRemarkId
                                           completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self commentsForClosingRemarkWithId:closingRemarkId
                                          count:100
                                       fromDate:nil
                                         toDate:nil
                              completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)commentsForClosingRemarkWithId:(ReadmillHighlightId)highlightId
                                                       count:(NSUInteger)count
                                                    fromDate:(NSDate *)fromDate
                                                      toDate:(NSDate *)toDate
                                           completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setValue:[NSNumber numberWithUnsignedInteger:count] forKey:@"count"];
    [parameters setValue:fromDate forKey:@"from"];
    [parameters setValue:toDate forKey:@"to"];
    
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d/comments",
                          [self closingRemarksEndpoint],
                          highlightId];
    
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:[parameters autorelease]
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)deleteCommentWithId:(ReadmillCommentId)commentId completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/%d", [self commentsEndpoint], commentId];
    return [self sendDeleteRequestToEndpoint:endpoint withParameters:nil completionHandler:completionHandler];
}

#pragma mark -
#pragma mark - Likes

- (ReadmillRequestOperation *)likesForHighlightWithId:(ReadmillHighlightId)highlightId
                                    completionHandler:(ReadmillAPICompletionHandler)completion
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/highlight/%d", [self likesEndpoint], highlightId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:nil
               shouldBeCalledUnauthorized:NO
                        completionHandler:completion];
}

- (ReadmillRequestOperation *)likeHighlightWithId:(ReadmillHighlightId)highlightId
                                completionHandler:(ReadmillAPICompletionHandler)completion
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/highlight/%d", [self likesEndpoint], highlightId];
    return [self sendPostRequestToEndpoint:endpoint
                            withParameters:nil
                         completionHandler:completion];
}

- (ReadmillRequestOperation *)unlikeHighlightWithId:(ReadmillHighlightId)highlightId
                                  completionHandler:(ReadmillAPICompletionHandler)completion
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/highlight/%d", [self likesEndpoint], highlightId];
    return [self sendDeleteRequestToEndpoint:endpoint
                              withParameters:nil
                           completionHandler:completion];
}

- (ReadmillRequestOperation *)likesForClosingRemarkWithId:(ReadmillClosingRemarkId)closingRemarkId
                                        completionHandler:(ReadmillAPICompletionHandler)completion
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/closing_remark/%d", [self likesEndpoint], closingRemarkId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:nil
               shouldBeCalledUnauthorized:NO
                        completionHandler:completion];
}

- (ReadmillRequestOperation *)likeClosingRemarkWithId:(ReadmillClosingRemarkId)closingRemarkId
                                    completionHandler:(ReadmillAPICompletionHandler)completion
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/closing_remark/%d", [self likesEndpoint], closingRemarkId];
    return [self sendPostRequestToEndpoint:endpoint
                            withParameters:nil
                         completionHandler:completion];
}

- (ReadmillRequestOperation *)unlikeClosingRemarkWithId:(ReadmillClosingRemarkId)closingRemarkId
                                      completionHandler:(ReadmillAPICompletionHandler)completion
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/closing_remark/%d", [self likesEndpoint], closingRemarkId];
    return [self sendDeleteRequestToEndpoint:endpoint
                              withParameters:nil
                           completionHandler:completion];
}

#pragma mark -
#pragma Connections

- (ReadmillRequestOperation *)connectionsForCurrentUserWithCompletionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = @"me/connections";
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:nil
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

#pragma mark
#pragma mark - Users

- (ReadmillRequestOperation *)usersWithParameters:(NSDictionary *)parameters
                                completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self sendGetRequestToEndpoint:@"users"
                           withParameters:parameters
               shouldBeCalledUnauthorized:YES
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)userWithId:(ReadmillUserId)userId
                       completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"users/%d", userId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:nil
               shouldBeCalledUnauthorized:YES
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)currentUserWithCompletionHandler:(ReadmillAPICompletionHandler)completionHandler
{    
    return [self sendGetRequestToEndpoint:@"me"
                           withParameters:nil
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)searchUsersUsingQuery:(NSString *)query
                                  completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"%@/search", [self usersEndpoint]];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [parameters setValue:query forKey:@"query"];
    
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:parameters
               shouldBeCalledUnauthorized:YES
                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        completionHandler:completionHandler];
}

- (NSURL *)avatarURLForUserWithId:(ReadmillUserId)userId
                       parameters:(NSDictionary *)parameters
{
    NSString *endpoint = [NSString stringWithFormat:@"users/%d/avatar?%@=%@", userId, kReadmillAPIClientIdKey, [self.apiConfiguration clientID]];
    for (NSString *key in [parameters allKeys]) {
        endpoint = [endpoint stringByAppendingFormat:@"&%@=%@", key, parameters[key]];
    }
    return [NSURL URLWithString:endpoint relativeToURL:self.apiConfiguration.apiBaseURL];
}

#pragma mark -
#pragma mark - Followings

- (ReadmillRequestOperation *)followersForUserWithId:(ReadmillUserId)userId
                                          parameters:(NSDictionary *)parameters
                                   completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"users/%d/followers", userId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:parameters
               shouldBeCalledUnauthorized:YES
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)followingsForUserWithId:(ReadmillUserId)userId
                                           parameters:(NSDictionary *)parameters
                                    completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"users/%d/followings", userId];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:parameters
               shouldBeCalledUnauthorized:YES
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)followUserWithId:(ReadmillUserId)userId
                             completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"followings/%d", userId];
    return [self sendPostRequestToEndpoint:endpoint
                            withParameters:nil
                         completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)followUsersWithIds:(NSArray *)userIds
                               completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *userIdsParameter = [userIds componentsJoinedByString:@","];
    NSDictionary *parameters = @{ @"user_ids" : userIdsParameter };
    return [self sendPostRequestToEndpoint:@"followings"
                            withParameters:parameters
                         completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)unfollowUserWithId:(ReadmillUserId)userId completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSString *endpoint = [NSString stringWithFormat:@"followings/%d", userId];
    return [self sendDeleteRequestToEndpoint:endpoint
                              withParameters:nil
                           completionHandler:completionHandler];
}



#pragma mark -
#pragma mark - Library

- (NSString *)endpointForLibraryItemWithId:(ReadmillLibraryItemId)itemId
{
    return [NSString stringWithFormat:@"%@/%d", [self libraryEndPoint], itemId];
}

- (ReadmillRequestOperation *)libraryItemWithId:(ReadmillLibraryItemId)libraryItemId
                              completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self sendGetRequestToEndpoint:[self endpointForLibraryItemWithId:libraryItemId]
                           withParameters:nil
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)updateLibraryItemWithId:(ReadmillLibraryItemId)libraryItemId
                                           parameters:(NSDictionary *)parameters
                                    completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self sendPutRequestToEndpoint:[self endpointForLibraryItemWithId:libraryItemId]
                           withParameters:parameters
                        completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)deleteLibraryItemWithId:(ReadmillLibraryItemId)libraryItemId
                                    completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    return [self sendDeleteRequestToEndpoint:[self endpointForLibraryItemWithId:libraryItemId]
                              withParameters:nil
                           completionHandler:completionHandler];
}

- (ReadmillRequestOperation *)libraryChangesWithLocalIds:(NSArray *)localIds
                                       completionHandler:(ReadmillAPICompletionHandler)completionHandler
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:[localIds componentsJoinedByString:@","]
                                                           forKey:kReadmillAPILibraryLocalIdsKey];
    
    NSString *endpoint = [[self libraryEndPoint] stringByAppendingPathComponent:@"compare"];
    return [self sendGetRequestToEndpoint:endpoint
                           withParameters:parameters
               shouldBeCalledUnauthorized:NO
                        completionHandler:completionHandler];
}

#pragma mark -
#pragma mark - Operation

- (ReadmillRequestOperation *)operationWithRequest:(NSURLRequest *)request
                                        completion:(ReadmillAPICompletionHandler)completionBlock
{
    NSAssert(request != nil, @"Request is nil!");
    static NSString * const LocationHeader = @"Location";
    
    // This block will be called when the asynchronous operation finishes
    ReadmillRequestOperationCompletionBlock connectionCompletionHandler = ^(NSHTTPURLResponse *response,
                                                                            NSData *responseData,
                                                                            NSError *connectionError) {
        @autoreleasepool {
            NSError *error = nil;
            
            // If we created something (201) or tried to create an existing
            // resource (409), we issue a GET request with the URL found
            // in the "Location" header that contains the resource.
            NSString *locationHeader = [[response allHeaderFields] valueForKey:LocationHeader];
            if ([response statusCode] == 409 && locationHeader != nil) {
                
                NSURL *locationURL = [NSURL URLWithString:locationHeader];
                NSURLRequest *newRequest = [self getRequestWithURL:locationURL
                                                        parameters:nil
                                        shouldBeCalledUnauthorized:NO
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                             error:&error];
                
                if (newRequest) {
                    // It's important that we return this resource ASAP
                    [self startPreparedRequest:newRequest
                                    completion:completionBlock
                                 queuePriority:NSOperationQueuePriorityVeryHigh];
                } else {
                    if (completionBlock) {
                        completionBlock(nil, error);
                    }
                }
            } else {
                // Parse the response
                id jsonResponse = [self parseResponse:response
                                     withResponseData:responseData
                                      connectionError:connectionError
                                                error:&error];
                
                if (connectionError || error) {
                    // Remove cached requests for errors
                    [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
                }
                
                // Execute the completionBlock
                if (completionBlock) {
                    completionBlock(jsonResponse, error);
                }
            }
        }
    };
    ReadmillRequestOperation *operation = [[[ReadmillRequestOperation alloc] initWithRequest:request
                                                                           completionHandler:connectionCompletionHandler] autorelease];
    
    return operation;
}


#pragma mark -
#pragma mark - Cancel operations

- (void)cancelAllOperations
{
    [queue cancelAllOperations];
}

@end


