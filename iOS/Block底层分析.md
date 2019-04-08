# Block底层研究方法

## 1.工具： clang
首先cd到代码文件目录
```c
cd /Users/user/Desktop/BlockClang/BlockClang 
```
再执行clang指令
```c
// xcode 10.0后，在使用模拟器编译情况下，前面需要添加xcrun -sdk iphonesimulator，否则编译报错
xcrun -sdk iphonesimulator clang -rewrite-objc main.m
```

其中main.m的代码如下：
```c
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

```

执行结果：
mian.m同级目录下会生成mian.cpp文件

## 2.mian.cpp文件分析
打开文件，会非常庞大，高达几万行代码。
这里只选取部分关键代码。
> 快速拖到代码最下面，不难看出 int main(int argc, const char * argv[]) 就是主函数的实现

```C
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 

        typedef void (*blk_t)(void);
        blk_t block = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA));
        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);
    }
    return 0;
}
```

#### (1)__main_block_impl_0
定义如下
```c
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int flags=0) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```

- mian：表示当前函数名
- block_impl：表示block起名统一对象
- 0 代表当前函数里面的第几个

#### (2)__block_impl
定义如下
```c
struct __block_impl {
  void *isa;
  int Flags;
  int Reserved;
  void *FuncPtr;
};
```
- isa, 指向所属指针的类型。 block的类型有三种： NSGlobalBlock，NSStackBlock，NSMallocBlock
- Flags， 标志变量，在实现block的内部操作时会用到
- Reserved，保留变量
- FuncPtr，block执行时调用的函数指针
不难看出，block结构体中也包含了isa指针，也就是说block也是一个对象。

#### （3）__main_block_desc_0
定义如下
```c
static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};
```
- reserved, 保留字段
- Block_size, block大小
在定义__main_block_desc_0结构体时，同时创建了一个__main_block_desc_0_DATA，并进行了赋值。

#### （4）__main_block_func_0
是block体内一个c++实现

```c
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
            printf("Hello, World!\n");
        }
```
> 总结： 
-  __main_block_impl_0的isa指针指向了_NSConcreteStackBlock
-  __main_block_impl_0的FunPtr指向了函数__main_block_func_0
-  __main_block_impl_0的Desc指向了__main_block_desc_0创建的对象__main_block_desc_0_DATA，其中记录了block结构体大小等信息
