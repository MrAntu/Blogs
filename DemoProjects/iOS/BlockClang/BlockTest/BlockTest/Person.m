//
//  Person.m
//  BlockTest
//
//  Created by weiwei.li on 2019/4/8.
//  Copyright © 2019 dd01.leo. All rights reserved.
//

#import "Person.h"

@implementation Person

- (void)test {
    Person *p = [[Person alloc] init];
    [p eat];
}

- (void)eat {
    printf("hello world");
}
@end
