//
//  NSArray+ObjectiveSugar.m
//  WidgetPush
//
//  Created by Marin Usalj on 5/7/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSArray+ObjectiveSugar.h"
#import "NSMutableArray+ObjectiveSugar.h"
#import "NSString+ObjectiveSugar.h"

static NSString * const OSMinusString = @"-";

@implementation NSArray (ObjectiveSugar)

- (id)sample {
    if (self.count == 0) return nil;

    NSUInteger index = arc4random_uniform((u_int32_t)self.count);
    return self[index];
}

- (id)objectForKeyedSubscript:(id)key {
    if ([key isKindOfClass:[NSString class]])
        return [self subarrayWithRange:[self rangeFromString:key]];

    else if ([key isKindOfClass:[NSValue class]])
        return [self subarrayWithRange:[key rangeValue]];

    else
        [NSException raise:NSInvalidArgumentException format:@"expected NSString or NSValue argument, got %@ instead", [key class]];

    return nil;
}

- (NSRange)rangeFromString:(NSString *)string {
    NSRange range = NSRangeFromString(string);

    if ([string containsString:@"..."]) {
        range.length = isBackwardsRange(string) ? (self.count - 2) - range.length : range.length - range.location;

    } else if ([string containsString:@".."]) {
        range.length = isBackwardsRange(string) ? (self.count - 1) - range.length : range.length - range.location + 1;
    }

    return range;
}

- (void)each:(void (^)(id object))block {
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        block(obj);
    }];
}

- (void)eachWithIndex:(void (^)(id object, NSUInteger index))block {
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        block(obj, idx);
    }];
}

- (void)each:(void (^)(id object))block options:(NSEnumerationOptions)options {
    [self enumerateObjectsWithOptions:options usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        block(obj);
    }];
}

- (void)eachWithIndex:(void (^)(id object, NSUInteger index))block options:(NSEnumerationOptions)options {
    [self enumerateObjectsWithOptions:options usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        block(obj, idx);
    }];
}

- (BOOL)includes:(id)object {
    return [self containsObject:object];
}

- (NSArray *)take:(NSUInteger)numberOfElements {
    return [self subarrayWithRange:NSMakeRange(0, MIN(numberOfElements, [self count]))];
}

- (NSArray *)takeWhile:(BOOL (^)(id object))block {
    NSMutableArray *array = [NSMutableArray array];

    for (id arrayObject in self) {
        if (block(arrayObject))
            [array addObject:arrayObject];

        else break;
    }

    return array;
}

- (NSArray *)map:(id (^)(id object))block {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.count];

    for (id object in self) {
        [array addObject:block(object) ?: [NSNull null]];
    }

    return array;
}

- (NSArray *)select:(BOOL (^)(id object))block {
    return [self filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return block(evaluatedObject);
    }]];
}

- (NSArray *)reject:(BOOL (^)(id object))block {
    return [self filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return !block(evaluatedObject);
    }]];
}

- (id)detect:(BOOL (^)(id object))block {
    for (id object in self) {
        if (block(object))
            return object;
    }
    return nil;
}

- (id)find:(BOOL (^)(id object))block {
    return [self detect:block];
}

- (NSArray *)flatten {
    NSMutableArray *array = [NSMutableArray array];

    for (id object in self) {
        if ([object isKindOfClass:NSArray.class]) {
            [array concat:[object flatten]];
        } else {
            [array addObject:object];
        }
    }

    return array;
}

- (NSArray *)compact {
    return [self select:^BOOL(id object) {
        return object != [NSNull null];
    }];
}

- (NSString *)join {
    return [self componentsJoinedByString:@""];
}

- (NSString *)join:(NSString *)separator {
    return [self componentsJoinedByString:separator];
}

- (NSArray *)sort {
    return [self sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)sortBy:(NSString*)key {
    return [self sortBy:key ascending:YES];
}

- (NSArray *)sortBy:(NSString*)key ascending:(BOOL)ascending {
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:key ascending:ascending];
    return [self sortedArrayUsingDescriptors:@[descriptor]];
}

- (NSArray *)reverse {
    return self.reverseObjectEnumerator.allObjects;
}

- (id)reduce:(id (^)(id accumulator, id object))block {
    return [self reduce:nil withBlock:block];
}

- (id)reduce:(id)initial withBlock:(id (^)(id accumulator, id object))block {
	id accumulator = initial;

	for(id object in self)
        accumulator = accumulator ? block(accumulator, object) : object;

	return accumulator;
}

- (id)reducePairs:(id)initial withBlock:(id (^)(id accumulator, id obj1, id obj2))block {
    id accumulator = initial;
    
    for (int i = 0; i < self.count - 1; i++) {
        id obj1 = self[i];
        id obj2 = self[i+1];
        accumulator = accumulator ? block(accumulator, obj1, obj2) : obj1;
    }
    
    return accumulator;
}

- (NSArray *)unique
{
  return [[NSOrderedSet orderedSetWithArray:self] array];
}

- (NSDictionary *)groupBy:(id (^)(id item))block
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (id item in self) {
        id key = block(item);
        NSMutableArray *group = [result objectForKey:key];
        if (!group) {
            group = [NSMutableArray array];
            [result setObject:group forKey:key];
        }
        [group addObject:item];
    }
    return result;
}

-(id)max:(NSComparisonResult (^)(id obj, id otherObj))aBlock
{
    return [self reduce:[self firstObject] withBlock:^id(id max, id obj) {
        return aBlock(max,obj) == NSOrderedAscending ? obj : max;
    }];
}

-(id)min:(NSComparisonResult (^)(id obj, id otherObj))aBlock
{
    return [self reduce:[self firstObject] withBlock:^id(id max, id obj) {
        return aBlock(max,obj) == NSOrderedDescending ? obj : max;
    }];
}

#pragma mark - Set operations

- (NSArray *)intersectionWithArray:(NSArray *)array {
    NSPredicate *intersectPredicate = [NSPredicate predicateWithFormat:@"SELF IN %@", array];
    return [self filteredArrayUsingPredicate:intersectPredicate];
}

- (NSArray *)unionWithArray:(NSArray *)array {
    NSArray *complement = [self relativeComplement:array];
    return [complement arrayByAddingObjectsFromArray:array];
}

- (NSArray *)relativeComplement:(NSArray *)array {
    NSPredicate *relativeComplementPredicate = [NSPredicate predicateWithFormat:@"NOT SELF IN %@", array];
    return [self filteredArrayUsingPredicate:relativeComplementPredicate];
}

- (NSArray *)symmetricDifference:(NSArray *)array {
    NSArray *aSubtractB = [self relativeComplement:array];
    NSArray *bSubtractA = [array relativeComplement:self];
    return [aSubtractB unionWithArray:bSubtractA];
}

#pragma mark - Private

static inline BOOL isBackwardsRange(NSString *rangeString) {
    return [rangeString containsString:OSMinusString];
}

#pragma mark - Aliases

- (NSArray *)filter:(BOOL (^)(id object))block
{
    return [self select:block];
}

- (id)anyObject {
    return [self sample];
}

- (id)first DEPRECATED_ATTRIBUTE {
    return [self firstObject];
}

- (id)last DEPRECATED_ATTRIBUTE {
    return [self lastObject];
}

@end

