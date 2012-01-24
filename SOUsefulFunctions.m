//
//  SOUsefulFunctions.m
//  Fotovino
//
//  Created by William Garrison on 1/23/12.
//  Copyright (c) 2012 Standard Orbit Software, LLC. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC (set -fobjc_arc flag on file)
#endif

#import "SOUsefulFunctions.h"

NSString *SOGeneratedUUID(void)
{
    NSString *UUID = nil;
    
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    if (uuidRef)
    {
        UUID = (__bridge_transfer NSString *) CFUUIDCreateString(NULL, uuidRef);
        CFRelease (uuidRef);
    }
    
    return UUID;
}
