//
//  FTAParseSync.m
//  FTASync
//
//  Created by Justin Bergen on 3/16/12.
//  Copyright (c) 2012 Five3 Apps, LLC. All rights reserved.
//

#import "FTAParseSync.h"

@implementation FTAParseSync

- (NSArray *)getObjectsOfClass:(NSString *)className updatedSince:(NSDate *)lastUpdate {
    PFQuery *query = [PFQuery queryWithClassName:className];
    
    if (lastUpdate) {
        [query whereKey:@"updatedAt" greaterThan:lastUpdate];
    }
    
    NSArray *returnObjects = [query findObjects];
    
    return returnObjects;
}

- (BOOL)putUpdatedObjects:(NSArray *)updatedObjects forClass:(NSEntityDescription *)entityDesc error:(NSError **)error {
    NSMutableArray *updatedParseObjects = [[NSMutableArray alloc] initWithCapacity:[updatedObjects count]];
    
    //Get parse objects for all updated objects
    for (FTASyncParent *localObject in updatedObjects) {
        PFObject *parseObject = [localObject FTA_parseObjectForObject];
        [updatedParseObjects addObject:parseObject];
    }
    NSUInteger updateCount = [updatedParseObjects count];
    
    //Get parse objects for all deleted objects
    NSString *defaultsKey = [NSString stringWithFormat:@"FTASyncDeleted%@", [entityDesc name]];
    NSArray *deletedLocalObjects = [[NSUserDefaults standardUserDefaults] objectForKey:defaultsKey];
    DLog(@"Preparing to create PFObjects for deletion: %@", deletedLocalObjects);
    for (NSString *objectId in deletedLocalObjects) {
        PFObject *parseObject = [PFObject objectWithClassName:[entityDesc name]];
        parseObject.objectId = objectId;
        //[parseObject setValue:[NSNumber numberWithBool:YES] forKey:@"deleted"];
        [parseObject setObject:[NSNumber numberWithInt:1] forKey:@"deleted"];
        [updatedParseObjects addObject:parseObject];
        DLog(@"Deleting PFObject: %@", parseObject);
    }
    NSUInteger deleteCount = [updatedParseObjects count] - updateCount;
    
    //Update objects on remote
    BOOL success = [PFObject saveAll:updatedParseObjects error:error];
    if (!success) {
        DLog(@"saveAll failed with:");
        return NO;
    }
    
    //Update local deleted objects with Parse results
    NSArray *deletedFromDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:defaultsKey];
    NSMutableArray *newDeletedLocalObjects = [[NSMutableArray alloc] initWithArray:deletedFromDefaults];
    [newDeletedLocalObjects removeObjectsInArray:deletedLocalObjects];
    [[NSUserDefaults standardUserDefaults] setObject:newDeletedLocalObjects forKey:defaultsKey];
    
    //Update local updated objects with Parse results
    [updatedParseObjects removeObjectsInRange:NSMakeRange(updateCount, deleteCount)];
    if ([updatedObjects count] != [updatedParseObjects count]) {
        ALog(@"%@", @"Local and Parse object arrays are out of sync!");
    }
    [updatedObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [obj FTA_updateObjectWithParseObject:[updatedParseObjects objectAtIndex:idx]];
    }];
    
    return YES;
}

- (BOOL)deleteObjects:(NSArray *)objects olderThan:(NSDate *)date {
    //TODO: This is the remote server cleanup method
    return YES;
}

@end
