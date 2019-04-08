//
//  main.m
//  BlockClang
//
//  Created by weiwei.li on 2019/4/8.
//  Copyright © 2019 dd01.leo. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <stdio.h>
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        typedef void (^blk_t)(void);
        blk_t block = ^{
            printf("Hello, World!\n");
        };
        block();
    }
    return 0;
}
