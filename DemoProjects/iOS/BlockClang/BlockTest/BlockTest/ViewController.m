//
//  ViewController.m
//  BlockTest
//
//  Created by weiwei.li on 2019/4/8.
//  Copyright © 2019 dd01.leo. All rights reserved.
//

#import "ViewController.h"

void(^block)(void) = ^ {
    printf("global Block");
};

void (^stackBlock)(void);

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //匿名函数
    int (*funcptr)(int) = &func;
    
    NSLog(@"%d",(*funcptr)(10));
    
    [self test1];
    [self test2];
    [self  test3];
}

int func(int count) {
    return 10;
}

//关于“带有自动变量（局部变量）”的含义，这是因为Block拥有捕获外部变量的功能。在Block中访问一个外部的局部变量，Block会持用它的临时状态，自动捕获变量值，外部局部变量的变化不会影响它的的状态。
- (void)test1 {
    int val = 10;
//    block 在实现时就会对它引用到的它所在方法中定义的栈变量进行一次只读拷贝，然后在 block 块内使用该只读拷贝；换句话说block截获自动变量的瞬时值；或者block捕获的是自动变量的副本。
    void (^blk)(void) = ^{
        printf("val=%d\n",val); // 10
    };
    val = 2;
    blk();
    
//    解决block不能修改自动变量的值，这一问题的另外一个办法是使用__block修饰符。
   __block int val1 = 10;
    void(^blk1)(void) = ^{
        printf("val=%d\n",val1); // 3
    };
    val1 = 3;
    blk1();
}

// Block与内存管理
//NSGlobalBlock是位于全局区的block，它是设置在程序的数据区域（.data区）中。
//
//NSStackBlock是位于栈区，超出变量作用域，栈上的Block以及 __block变量都被销毁。
//
//NSMallocBlock是位于堆区，在变量作用域结束时不受影响。

// 1.NSGlobalBlock

- (void)test2 {
    block();
}

//2. NSStackBlock
//block在ARC和非ARC下有巨大差别。多数情况下，ARC下会默认把栈block被会直接拷贝生成到堆上

- (void)test3 {
    NSInteger i = 110;
    stackBlock = ^ {
        NSLog(@"%ld",i);
    };
    stackBlock();
}
@end
