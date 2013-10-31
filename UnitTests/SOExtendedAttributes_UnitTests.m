//
//  SOExtendedAttributes_UnitTests.m
//  SOExtendedAttributes.UnitTests
//
//  Created by William Garrison on 1/23/12.
//  Copyright (c) 2012 Standard Orbit Software, LLC. All rights reserved.
//

#import "NSURL+SOExtendedAttributes.h"
#import "SOUsefulFunctions.h"
#include <sys/xattr.h>

@interface SOExtendedAttributes_UnitTests : SenTestCase
{
    NSURL *targetURL;
}
@end

@implementation SOExtendedAttributes_UnitTests


#pragma mark
#pragma mark Fixture

- (BOOL) createTestURLForTest:(SEL)testSelector
{
    BOOL didCreate = NO;
    
    targetURL = [NSURL fileURLWithPathComponents:[NSArray arrayWithObjects:NSTemporaryDirectory(), NSStringFromSelector(testSelector), SOGeneratedUUID(), nil]];
    
    if (targetURL)
    {
        /* First create the intermediate parent directory */
        didCreate = [[NSFileManager defaultManager] createDirectoryAtURL:[targetURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
        
        /* Then try creating an empty test file. */
        if (didCreate) {
            didCreate = [[NSFileManager defaultManager] createFileAtPath:[targetURL path]  contents:[NSData data] attributes:nil];
        }
    }
    
    return didCreate;
}


- (void) setUp
{
    [super setUp];
}

- (void) tearDown
{
    if (targetURL) {
        if ( ![[NSFileManager defaultManager] removeItemAtPath:[targetURL path] error:nil]) {
            NSLog (@"Couldn't cleanup test file: %@", targetURL);
        }
    }
    
    [super tearDown];
}

#pragma mark - Error Reporting Tests

- (void) testCollectedErrrors
{
    /* Test that underlying errors generated from xattr are collected and reported properly. */
    
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    /* Create a test file */
    

    
    NSString *excessivelyLongName1 = @"Loremipsumdolorsitametconsecteturadipisicingelitseddoeiusmodtemporincididuntutlaboreetdoloremagnaaliqua.Utenimadminimveniamwangchung";
    NSString *excessivelyLongName2 = @"Loremipsumdolorsitametconsecteturadipisicingelitseddoeiusmodtemporincididuntutlaboreetdoloremagnaaliqua.Utenimadminimveniamwangchungscooby";
    NSString *excessivelyLongName3 = @"Loremipsumdolorsitametconsecteturadipisicingelitseddoeiusmodtemporincididuntutlaboreetdoloremagnaaliqua.Utenimadminimveniamwangchungshaggy";
    
    NSDictionary *badlyNamedAttribs = [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"LexLuthor" ,excessivelyLongName1,
                                       @"Magneto", excessivelyLongName2,
                                       @"KhanNoonianSingh", excessivelyLongName3,
                                       nil
                                       ];
    
    BOOL didAdd = [targetURL setExtendedAttributes:badlyNamedAttribs error:&error];
    
    NSLog (@"error: %@", error);
    
    STAssertFalse (didAdd, @"Expected failure");
    STAssertNotNil (error, @"Expected an error report");
    STAssertTrue ( [[[error userInfo] objectForKey:SOUnderlyingErrorsKey] isKindOfClass:[NSArray class]], @"Expected array of collected errors.");
    STAssertTrue ( [[[error userInfo] objectForKey:SOUnderlyingErrorsKey] count] > 0, @"Expected multiple errors to be collected into an array.");
}

#pragma mark
#pragma mark Batch Attribute Tests

- (void) testAddRetrieveBatchOfAttributes
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    NSMutableDictionary *testAttributes = [NSMutableDictionary dictionary];
    [testAttributes setObject:@"Groucho" forKey:@"Favorite Mood"];
    [testAttributes setObject:@"Harpo" forKey:@"Name of high school"];
    [testAttributes setObject:@"Chico" forKey:@"City in California"];
    [testAttributes setObject:[NSDate date] forKey:@"Birthday"];
    
    /* Test batch add */
    BOOL didAdd = [targetURL setExtendedAttributes:testAttributes error:&error];
    STAssertTrue (didAdd, @"%@", error);
    
    /* Test batch retrieve */
    error = nil;
    NSDictionary *retrievedAttributes = [targetURL extendedAttributesWithError:&error];
    STAssertNotNil (retrievedAttributes, @"postcondition violated");
    STAssertTrue ([retrievedAttributes isEqualToDictionary:testAttributes], @"postcondition violated");
}

- (void) testHasAttributes
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    /* Create a test file */
    

    
    NSMutableDictionary *testAttributes = [NSMutableDictionary dictionary];
    [testAttributes setObject:@"Groucho" forKey:@"Favorite Mood"];
    [testAttributes setObject:@"Harpo" forKey:@"Name of high school"];
    [testAttributes setObject:@"Chico" forKey:@"City in California"];
    [testAttributes setObject:[NSDate date] forKey:@"Birthday"];
    
    BOOL didAdd = [targetURL setExtendedAttributes:testAttributes error:&error];
    STAssertTrue (didAdd, @"%@", error);
    
    STAssertTrue ([targetURL hasExtendedAttributeWithName:@"Favorite Mood"], @"postcondition violated");
    STAssertTrue ([targetURL hasExtendedAttributeWithName:@"Birthday"], @"postcondition violated");
    STAssertFalse ([targetURL hasExtendedAttributeWithName:@"Total Eclipse of the Heart"], @"postcondition violated");
}

#pragma mark -
#pragma mark Removal Tests

- (void) testRemoveNonexistentAttribute
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    /* Create a test file */
    

    
    /* Removing non-existent attribs is OK. */
    BOOL didRemove = [targetURL removeExtendedAttributeWithName:@"Jughead" error:&error];
    STAssertTrue (didRemove, @"%@", error);
}

- (void) testAddRemoveSingleAttribute
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    
    /* Create a test file */
    

    
    NSError *error = nil;
    NSString *attribName = @"net.standardorbit.latinPlaceholderText";
    id attribValue = @"Lorem ipsum dolor sit amet";
    
    /* Test setting an extended attribute value */
    
    STAssertTrue ( [targetURL setExtendedAttributeValue:attribValue forName:attribName error:&error], @"%@", error);
    
    /* Test retrieving the extended attribute value */
    
    id retrievedValue = [targetURL valueOfExtendedAttributeWithName:attribName error:&error];
    STAssertNotNil (retrievedValue, @"%@", error);
    
    /* Remove the extended attribute */
    
    BOOL didRemove = [targetURL removeExtendedAttributeWithName:attribName error:&error];
    STAssertTrue (didRemove, @"%@; %@", error, [error userInfo]);
}

#pragma mark -
#pragma mark Single Attribute Tests

- (void) testStringAttribute
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    
    NSString *flog = @"flog";
    BOOL didSet = [targetURL setExtendedAttributeValue:flog forName:@"flogger" error:&error];
    STAssertTrue (didSet, @"%@", error);
    
    error = nil;
    id retrievedValue = [targetURL valueOfExtendedAttributeWithName:@"flogger" error:&error];
    STAssertNotNil (retrievedValue, @"%@",error);
    
    STAssertTrue ([retrievedValue isKindOfClass:[NSString class]], @"postcondition violated");
    STAssertTrue ([flog isEqualToString:retrievedValue], @"postcondition violated");
}

- (void) testArrayAttribute
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;

    
    NSArray *colors = [NSArray arrayWithObjects:@"red", @"orange", @"yellow", @"green", @"blue", @"violet", nil];
    STAssertTrue ([targetURL setExtendedAttributeValue:colors forName:@"colors" error:&error], @"%@", error);
    
    error = nil;
    id retrievedValue = [targetURL valueOfExtendedAttributeWithName:@"colors" error:&error];
    STAssertNotNil (retrievedValue, @"%@", error);
    STAssertTrue ([retrievedValue isKindOfClass:[NSArray class]], @"postcondition violated");
    STAssertTrue ([colors isEqualToArray:retrievedValue], @"postcondition violated");
}

- (void) testDictionaryAttribute
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    NSMutableDictionary *movieInfo = [NSMutableDictionary dictionary];
    [movieInfo setObject:@"Star Wars" forKey:@"title"];
    [movieInfo setObject:@"George Lucas" forKey:@"director"];
    
    NSArray *talent = [NSArray arrayWithObjects:@"Mark Hamill", @"Carrie Fisher", @"Harrison Ford", nil];
    [movieInfo setObject:talent forKey:@"talent"];
    
    STAssertTrue ([targetURL setExtendedAttributeValue:movieInfo forName:@"movieInfo" error:&error], @"%@", error);
    
    error = nil;
    id retrievedValue = [targetURL valueOfExtendedAttributeWithName:@"movieInfo" error:&error];
    STAssertNotNil (retrievedValue, @"%@", error);
    STAssertTrue ([retrievedValue isKindOfClass:[NSDictionary class]], @"postcondition violated");
    STAssertTrue ([movieInfo isEqualToDictionary:retrievedValue], @"postcondition violated");
}

- (void) testNumberAttribute
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    /* Create a test file */
    
    id testNumber = [NSNumber numberWithFloat:6.28];
    
    STAssertTrue ([targetURL setExtendedAttributeValue:testNumber forName:@"number" error:&error], @"%@", error);
    
    error = nil;
    id retrievedValue = [targetURL valueOfExtendedAttributeWithName:@"number" error:&error];
    STAssertNotNil (retrievedValue, @"%@", error);
    STAssertTrue ([retrievedValue isKindOfClass:[NSNumber class]], @"postcondition violated");
    STAssertTrue ([testNumber isEqualToNumber:retrievedValue], @"postcondition violated");
}

- (void) testNullAttribute
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    id testNull = [NSNull null];
    
    STAssertFalse ([targetURL setExtendedAttributeValue:testNull forName:@"null" error:&error], @"%@", error);
    STAssertTrue ([error code] == SOExtendedAttributesValueCantBeSerialized, @"postcondition violated");
}

- (void) testBooleanYes
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    
    id testBoolean = (id)kCFBooleanTrue;
    STAssertTrue ([targetURL setExtendedAttributeValue:testBoolean forName:@"boolean" error:&error], @"%@", error);
    
    error = nil;
    id retrievedValue = [targetURL valueOfExtendedAttributeWithName:@"boolean" error:&error];
    STAssertNotNil (retrievedValue, @"%@", error);
    STAssertTrue ([retrievedValue isKindOfClass:[NSNumber class]], @"postcondition violated");
    STAssertTrue ([testBoolean isEqualToNumber:retrievedValue], @"postcondition violated");
}

- (void) testBooleanNo
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    /* Create a test file */
    

    
    id testBoolean = (id)kCFBooleanFalse;
    STAssertTrue ([targetURL setExtendedAttributeValue:testBoolean forName:@"boolean" error:&error], @"%@", error);
    
    error = nil;
    id retrievedValue = [targetURL valueOfExtendedAttributeWithName:@"boolean" error:&error];
    STAssertNotNil (retrievedValue, @"%@", error);
    STAssertTrue ([retrievedValue isKindOfClass:[NSNumber class]], @"postcondition violated");
    STAssertTrue ([testBoolean isEqualToNumber:retrievedValue], @"postcondition violated");
}

#pragma mark
#pragma mark Bad Parameter Tests

- (void) testAttributeNameTooLong
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    /* Create a test file */
    

    
    NSArray *wordList = [NSArray arrayWithObjects:@"red", @"orange", @"yellow", @"green", @"blue", @"violet", nil];
    NSMutableString *WayTooLongName = [NSMutableString string];
    while ([WayTooLongName length] <= XATTR_MAXNAMELEN)
    {
        [WayTooLongName appendString:[wordList objectAtIndex:(arc4random() % [wordList count])]];
    }
    
    STAssertFalse ([targetURL setExtendedAttributeValue:@"something" forName:WayTooLongName error:&error], @"%@", error);
    STAssertTrue ([error code] == ENAMETOOLONG, @"postcondition violated");
}


- (void) testAddAttributeEmptyName
{
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    NSError *error = nil;
    
    // test empty name
    STAssertThrows ([targetURL setExtendedAttributeValue:nil forName:@"" error:&error], @"expected param exception");
    
    // Test nil name
    error = nil;
    STAssertThrows ([targetURL setExtendedAttributeValue:nil forName:nil error:&error], @"expected param exception");
}

- (void) testAccessAttributeEmptyName
{
    NSError *error = nil;
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    
    // test empty name
    STAssertThrows ([targetURL valueOfExtendedAttributeWithName:@"" error:&error], @"expected param exception");
    
    // Test nil name
    error = nil;
    STAssertThrows ([targetURL valueOfExtendedAttributeWithName:nil error:&error], @"expected param exception");
}

- (void) testRemoveAttributeEmptyName
{
    NSError *error = nil;
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    
    // test empty name
    STAssertThrows ([targetURL removeExtendedAttributeWithName:@"" error:&error], @"expected param exception");
    
    // Test nil name
    error = nil;
    STAssertThrows ([targetURL removeExtendedAttributeWithName:nil error:&error], @"expected param exception");
    
}

- (void) testHasAttributeWithEmptyName
{
    NSError *error = nil;
    STAssertTrue([self createTestURLForTest:_cmd], @"Couldn't create test file");
    
    // test empty name
    STAssertThrows ([targetURL hasExtendedAttributeWithName:@""], @"expected param exception");
    
    // Test nil name
    error = nil;
    STAssertThrows ([targetURL hasExtendedAttributeWithName:nil], @"expected param exception");
}

- (void) testNonFileURL
{
    NSURL *url = [NSURL URLWithString:@"http://www.apple.com"];
    
    STAssertThrows ([url extendedAttributesWithError:NULL], @"expected NSInternalConsistencyExpection");
    STAssertThrows ([url setExtendedAttributes:[NSDictionary dictionary] error:NULL], @"expected NSInternalConsistencyExpection");
    
    STAssertThrows ([url hasExtendedAttributeWithName:@"bob"], @"expected NSInternalConsistencyExpection");
    
    STAssertThrows ([url setExtendedAttributeValue:nil forName:@"bob" error:NULL], @"expected NSInternalConsistencyExpection");
    STAssertThrows ([url valueOfExtendedAttributeWithName:@"bob" error:NULL], @"expected NSInternalConsistencyExpection");
    
    STAssertThrows ([url removeExtendedAttributeWithName:@"bob" error:NULL], @"expected NSInternalConsistencyExpection");
}


@end
