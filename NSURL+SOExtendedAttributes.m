
/*
 NSURL+SOExtendedAttributes
 
 Copyright 2012 Standard Orbit Software, LLC. All rights reserved.
 License at the bottom of the file.
 */

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC (set -fobjc_arc flag on file)
#endif

#import <Foundation/Foundation.h>
#import "NSURL+SOExtendedAttributes.h"
#import <sys/xattr.h>

NSString * const iCloudDoNotBackupAttributeName = @"com.apple.MobileBackup";
NSString * const SOExtendedAttributesErrorDomain = @"SOExtendedAttributesErrorDomain";

/* Use default options with xattr API that don't resolve symlinks and show the HFS compression extended attribute. */

static int xattrDefaultOptions = XATTR_NOFOLLOW | XATTR_SHOWCOMPRESSION;

/* Make an NSError from the global errno and optionally the url */
static inline NSError *SOPOSIXErrorForURL(NSURL *url)
{
    int posixErr = errno;
    NSString *errDesc = [NSString stringWithUTF8String:strerror(posixErr)];
    NSMutableDictionary *errInfo = [NSMutableDictionary dictionary];
    [errInfo setObject:errDesc forKey:NSLocalizedDescriptionKey];
    
    if (url)
    {
        [errInfo setObject:url forKey:NSURLErrorKey];
    }
    
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:posixErr userInfo:errInfo];
}

@implementation NSURL (SOExtendedAttributes)


- (NSArray *) namesOfExtendedAttributesWithError:(NSError * __autoreleasing *)outError
{
    if (![self isFileURL]) [NSException raise:NSInternalInconsistencyException format:@"%s only valid on file URLs", __PRETTY_FUNCTION__];
    
    NSMutableArray *attributeNames = [[NSMutableArray alloc] init];
    
    @autoreleasepool
    {
        /* Get attributes names. Bail with nil dictionary if problem */
        
        const char *itemPath = [[self path] fileSystemRepresentation];
        
        /* Get the size of the attributes list, then extract each name as an NSString. */
        
        NSMutableData *namesBuffer = nil;
        
        ssize_t bufferSize = listxattr (itemPath, NULL, SIZE_MAX, xattrDefaultOptions);
        if (bufferSize > 0)
        {
            namesBuffer = [NSMutableData dataWithLength:bufferSize];
            bufferSize = listxattr (itemPath, [namesBuffer mutableBytes], [namesBuffer length], xattrDefaultOptions );
        }
        
        /* No names? Bail now with empty list. */
        if (bufferSize == 0) return attributeNames;
        
        /* Problemo? Bail now with the POSIX error. */
        if (bufferSize == -1)
        {
            attributeNames = nil;
            if (outError) *outError = SOPOSIXErrorForURL(self);
            return nil;
        }
        
        /* Parse the name buffer for attribute names.
         
         Iterate the buffer character by character, looking for a NULL byte.
         When found, collect the range of bytes into an NSString and cache in our names list.
         */
        
        uintptr_t ptr_startOfBuffer = (uintptr_t)[namesBuffer mutableBytes];
        uintptr_t ptr_startOfName = ptr_startOfBuffer;
        
        for (size_t x = 0; x < bufferSize; x++ )
        {
            /* Advance current byte pointer */
            
            uintptr_t ptr_currentByte = ptr_startOfBuffer + x;
            
            /* Check for the end of a name */
            
            if ( *((char *)ptr_currentByte) == 0x0 )
            {
                /* Collect the attribute name */
                
                NSString *name = [[NSString alloc] initWithUTF8String:(char *)ptr_startOfName];
                [attributeNames addObject: name];
                name = nil;
                
                /* Reset the start of name pointer */
                
                ptr_startOfName = ptr_currentByte + 1;
            }
        }
    }
    
    return attributeNames;
}

#pragma mark -
#pragma mark Batch Attributes

- (NSDictionary *) extendedAttributesWithError:(NSError * __autoreleasing *)outError
{
    if (![self isFileURL]) [NSException raise:NSInternalInconsistencyException format:@"%s only valid on file URLs", __PRETTY_FUNCTION__];
    
    NSMutableDictionary *xattrs = nil;
    
    @autoreleasepool
    {
        NSArray *attributeNames = [self namesOfExtendedAttributesWithError:outError];
        if (attributeNames == nil) return nil;
        
        /* Pull the value for each found extended attribute. */
        
        xattrs = [[NSMutableDictionary alloc] initWithCapacity:[attributeNames count]];
        
        NSMutableArray *collectedErrors = [NSMutableArray array];
        
        for (NSString *name in attributeNames)
        {
            NSError *error = nil;
            id value = [self valueOfExtendedAttributeWithName:name error:&error];
            
            if (value)
            {
                [xattrs setObject:value forKey:name];
            }
            else
            {
                if (error) [collectedErrors addObject:error];
            }
        }
        
        /* Did we get any errors? */
        
        BOOL hasErrors = [collectedErrors count] > 0;
        if (hasErrors && outError)
        {
            NSMutableDictionary *errInfo = [NSMutableDictionary dictionary];
            [errInfo setObject:self forKey:NSURLErrorKey];
            [errInfo setObject:collectedErrors forKey:NSUnderlyingErrorKey];
            *outError = [NSError errorWithDomain:SOExtendedAttributesErrorDomain code:SOExtendedAttributesGetValueError userInfo:errInfo];
        }
    }
    
    return xattrs;
}

- (BOOL) setExtendedAttributes:(NSDictionary *)attributes error:(NSError * __autoreleasing *)outError
{
    if (![self isFileURL]) [NSException raise:NSInternalInconsistencyException format:@"%s only valid on file URLs", __PRETTY_FUNCTION__];
    
    /* It is OK but silly to pass in empty attributes. */
    
    if ([attributes count] == 0) return YES;
    
    
    /* Attempt to set all attribute values in the dictionary. Any individual errors are collected and returned as a group. */
    
    __block NSMutableArray *collectedErrors = [NSMutableArray array];
    [attributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSError *error = nil;
        if (NO == [self setExtendedAttributeValue:obj forName:key error:&error])
        {
            [collectedErrors addObject:error];
        }
    }];
    
    /* Did we get any errors? */
    
    BOOL hasErrors = [collectedErrors count] > 0;
    if (hasErrors && outError)
    {
        NSMutableDictionary *errInfo = [NSMutableDictionary dictionary];
        [errInfo setObject:self forKey:NSURLErrorKey];
        [errInfo setObject:collectedErrors forKey:NSUnderlyingErrorKey];
        *outError = [NSError errorWithDomain:SOExtendedAttributesErrorDomain code:SOExtendedAttributesSetValueError userInfo:errInfo];
        return NO;
    }
    
    return YES;
}

#pragma mark -
#pragma mark Individual Attributes

- (BOOL) hasExtendedAttributeWithName:(NSString *)name
{
    if (![self isFileURL]) [NSException raise:NSInternalInconsistencyException format:@"%s only valid on file URLs", __PRETTY_FUNCTION__];
    if (!name || [name isEqualToString:@""]) [NSException raise:NSInvalidArgumentException format:@"%s name parameter can't be nil", __PRETTY_FUNCTION__];
    
    NSError *error = nil;
    NSArray *attributeNames = [self namesOfExtendedAttributesWithError:&error];
    
    if (!attributeNames)
    {
        NSLog (@"ERROR: Could not get list of attributes names: %@; %@", error, [error userInfo]);
    }
    return [attributeNames containsObject:name];
}

- (id) valueOfExtendedAttributeWithName:(NSString *)name error:(NSError * __autoreleasing *)outError
{
    if (![self isFileURL]) [NSException raise:NSInternalInconsistencyException format:@"%s only valid on file URLs", __PRETTY_FUNCTION__];
    if (!name || [name isEqualToString:@""]) [NSException raise:NSInvalidArgumentException format:@"%s name parameter can't be nil", __PRETTY_FUNCTION__];
    
    id retrievedValue = nil;
    
    @autoreleasepool
    {
        /* Get the size of the attribute value and pull it into an NSData is possible */
        
        const char *itemPath = [[self path] fileSystemRepresentation];
        
        NSMutableData *data = [NSData data];
        
        ssize_t dataSize = getxattr (itemPath, [name UTF8String], NULL, SIZE_MAX, 0, xattrDefaultOptions);
        if (dataSize > 0)
        {
            data = [NSMutableData dataWithLength: dataSize];
            dataSize = getxattr (itemPath, [name UTF8String], [data mutableBytes], [data length], 0, xattrDefaultOptions );
        }
        
        /* Problemo? Bail out with error, ditching all collected attributes */
        
        if (dataSize == -1)
        {
            data = nil;
            if (outError) *outError = SOPOSIXErrorForURL(self);
            
        } else {
            
            /* Translate from encoded binary plist */
            
            retrievedValue = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:outError];
        }
    }
    
    return retrievedValue;
}

- (BOOL) setExtendedAttributeValue:(id)value forName:(NSString *)name error:(NSError * __autoreleasing *)outError
{
    if (![self isFileURL]) [NSException raise:NSInternalInconsistencyException format:@"%s only valid on file URLs", __PRETTY_FUNCTION__];
    if (!name || [name isEqualToString:@""]) [NSException raise:NSInvalidArgumentException format:@"%s name parameter can't be nil", __PRETTY_FUNCTION__];
    
    /* If value can be serialized as a binary plist, do so and store in extended attributes */
    
    if ([NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0])
    {
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:0 error:outError];
        
        int err = setxattr ( [[self path] fileSystemRepresentation], [name UTF8String], [data bytes], [data length], 0, XATTR_NOFOLLOW);
        if (err != 0)
        {
            if (outError) *outError = SOPOSIXErrorForURL(self);
            return NO;
        }
    }
    else
    {
        if (outError)
        {
            NSMutableDictionary *errInfo = [NSMutableDictionary dictionary];
            [errInfo setObject:[NSString stringWithFormat:@"Value of class %@ cannot be serialized into a plist", NSStringFromClass([value class])] forKey:NSLocalizedDescriptionKey];
            [errInfo setObject:value forKey:@"value"];
            *outError = [NSError errorWithDomain:SOExtendedAttributesErrorDomain code:SOExtendedAttributesValueCantBeSerialized userInfo:errInfo];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL) removeExtendedAttributeWithName:(NSString *)name error:(NSError * __autoreleasing *)outError
{
    if (![self isFileURL]) [NSException raise:NSInternalInconsistencyException format:@"%s only valid on file URLs", __PRETTY_FUNCTION__];
    if (!name || [name isEqualToString:@""]) [NSException raise:NSInvalidArgumentException format:@"%s name parameter can't be nil", __PRETTY_FUNCTION__];
    
    int err = removexattr([[self path] fileSystemRepresentation], [name UTF8String], xattrDefaultOptions);
    if (err != 0)
    {
        /* Ignore any ENOATTR error ('attribute not found'), but capture and return all others. */
        if (errno != ENOATTR)
        {
            if (outError) *outError = SOPOSIXErrorForURL(self);
            return NO;
        }
    }
    
    return YES;
}

@end

/*
 Copyright (c) 2012, Standard Orbit Software, LLC. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of the Standard Orbit Software, LLC nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */