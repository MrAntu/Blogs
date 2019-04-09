# Block底层研究方法

## 1.工具： clang
首先cd到代码文件目录
```c
cd /Users/user/Desktop/BlockClang/BlockClang 
```
再执行clang指令
```c
// xcode 10.0后，
xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc main.m
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


# Block外部变量捕获
#### 1.捕获局部基本类型变量
mian.m文件如下：
```c

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int age = 10;
        void(^block)(int ,int) = ^(int a, int b){
            NSLog(@"this is block,a = %d,b = %d",a,b);
            NSLog(@"this is block,age = %d",age);
        };
        block(1,9);
    }
    return 0;
}

```

clang后代码：
```c
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  int age; //block结构体中，多生成一个age变量，和block体外的变量名字一样
    
    //初始化方法中，也会增加一个_age参数。 并对 age(_age) 相当于age = _age,对于基本类型变量的赋值，相当于直接拷贝
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int _age, int flags=0) : age(_age) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself, int a, int b) {
    //函数体中，直接获取block_impl结果体中的age，和外部变量无关
  int age = __cself->age; // bound by copy

            NSLog((NSString *)&__NSConstantStringImpl__var_folders_9r_tb39pygj2jq_9m64l9fjkyb80000gp_T_main_665a96_mi_0,a,b);
            NSLog((NSString *)&__NSConstantStringImpl__var_folders_9r_tb39pygj2jq_9m64l9fjkyb80000gp_T_main_665a96_mi_1,age);
        }

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        int age = 10;
        //初始化多一个age参数
        void(*block)(int ,int) = ((void (*)(int, int))&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, age));
        ((void (*)(__block_impl *, int, int))((__block_impl *)block)->FuncPtr)((__block_impl *)block, 1, 9);
    }
    return 0;
}
```

#### 2.捕获auto,static基本类型变量
mian.m中代码如下
```c
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        auto int a = 10;
        static int b = 11;
        void(^block)(void) = ^{
            NSLog(@"a = %d, b = %d", a,b); // a = 10, b = 2
        };
        a = 1;
        b = 2;
        block();
    }
    return 0;
}

```
clang后主要部门代码如下
```c
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  //对于auto声明的局部变量，和普通的没有任何区别，都是赋值操作
  int a;
  // 对于static声明的变量，内部声明的是个指针，指向于外部捕获的变量地址，当外部的变量变化是，__main_block_func_0中可以实时的捕获到
  int *b;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int _a, int *_b, int flags=0) : a(_a), b(_b) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  int a = __cself->a; // bound by copy
  int *b = __cself->b; // bound by copy

            NSLog((NSString *)&__NSConstantStringImpl__var_folders_9r_tb39pygj2jq_9m64l9fjkyb80000gp_T_main_0d5afb_mi_0, a,(*b));
        }

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        auto int a = 10;
        static int b = 11;
        // &b传入的为地址。可以实时的捕获
        void(*block)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, a, &b));
        a = 1;
        b = 2;
        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);
    }
    return 0;
}
static struct IMAGE_INFO { unsigned version; unsigned flag; } _OBJC_IMAGE_INFO = { 0, 2 };

```

#### 3.捕获全局基本类型变量
全局变量不受影响。直接访问
```c
int a = 10;
static int b = 11;
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        void(^block)(void) = ^{
            NSLog(@"hello, a = %d, b = %d", a,b);
        };
        a = 1;
        b = 2;
        block();
    }
    return 0;
}
// log hello, a = 1, b = 2
```

#### 4.捕获对象和__weak修饰
main.m代码如下：
```c
  Person *p = [[Person alloc] init];
        p.age = 12;
        // __weak修饰，block不会对Person进行强引用，block执行完，就会释放
        __weak Person *weakPerson = p;
        void(^block)(void) = ^{
            NSLog(@"age = %ld", weakPerson.age); // age = 12
        };
        block();
```
clang代码，__weak修饰变量，需要告知编译器使用ARC环境及版本号否则会报错，添加说明-fobjc-arc -fobjc-runtime=ios-8.0.0
```C
xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc -fobjc-arc -fobjc-runtime=ios-8.0.0 main.m

```
c++代码如下：
```c
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
    // 生成一个__weak修饰的对象
  Person *__weak weakPerson;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, Person *__weak _weakPerson, int flags=0) : weakPerson(_weakPerson) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  Person *__weak weakPerson = __cself->weakPerson; // bound by copy

            NSLog((NSString *)&__NSConstantStringImpl__var_folders_9r_tb39pygj2jq_9m64l9fjkyb80000gp_T_main_c91a6f_mi_0, ((NSInteger (*)(id, SEL))(void *)objc_msgSend)((id)weakPerson, sel_registerName("age")));
        }
        
        //新增的copy方法
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->weakPerson, (void*)src->weakPerson, 3/*BLOCK_FIELD_IS_OBJECT*/);}

//新增的dispose方法
static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->weakPerson, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
    //多了两个方法，__main_block_copy_0 和 __main_block_dispose_0
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};


int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        Person *p = ((Person *(*)(id, SEL))(void *)objc_msgSend)((id)((Person *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("Person"), sel_registerName("alloc")), sel_registerName("init"));
        ((void (*)(id, SEL, NSInteger))(void *)objc_msgSend)((id)p, sel_registerName("setAge:"), (NSInteger)12);

        __attribute__((objc_ownership(weak))) Person *weakPerson = p;
        void(*block)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, weakPerson, 570425344));
        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);
    }
    return 0;
}
static struct IMAGE_INFO { unsigned version; unsigned flag; } _OBJC_IMAGE_INFO = { 0, 2 };

```

> 代码可知，__weak修饰的变量，在结构体中也是使用__weak修饰
> 当block捕获的是个对象时，__main_block_desc_0结构体中会多出两个函数。copy和dispose
> __main_block_copy_0函数，当block进行copy操作的时候就会自动调用
> __main_block_dispose_0函数，当block从堆中移除时就会自动调用

总结：
> 一旦block中捕获的变量为对象类型，block结构体中的__main_block_desc_0会出两个参数copy和dispose。因为访问的是个对象，block希望拥有这个对象，就需要对对象进行引用，也就是进行内存管理的操作。比如说对对象进行retarn操作，因此一旦block捕获的变量是对象类型就会会自动生成copy和dispose来对内部引用的对象进行内存管理

> 当block内部访问了对象类型的auto变量时，如果block是在栈上，block内部不会对person产生强引用。不论block结构体内部的变量是__strong修饰还是__weak修饰，都不会对变量产生强引用

> 如果block被拷贝到堆上。copy函数会调用_Block_object_assign函数，根据auto变量的修饰符（__strong，__weak，unsafe_unretained）做出相应的操作，形成强引用或者弱引用

> 如果block从堆中移除，dispose函数会调用_Block_object_dispose函数，自动释放引用的auto变量。

#### 5.__block修饰，可以在block内部修改值
mian.m代码如下
```c
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        __block int age = 10;
        void(^block)(void) = ^{
            age = 20;
            printf("block-- age = %d\n",age); //age = 20
        };
        block();
        printf("age = %d\n",age); // age = 20

    }
    return 0;
}
```
clang后代码如下

```C
//新增byref结构体
struct __Block_byref_age_0 {
  void *__isa; //isa指针，说明是个对象
__Block_byref_age_0 *__forwarding; // 结构体自己内存地址
 int __flags; //标志
 int __size; //大小
 int age; //真正存储变量的地方
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
    //变成__Block_byref_age_0对象
  __Block_byref_age_0 *age; // by ref
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, __Block_byref_age_0 *_age, int flags=0) : age(_age->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  __Block_byref_age_0 *age = __cself->age; // bound by ref

            (age->__forwarding->age) = 20;
            printf("block-- age = %d\n",(age->__forwarding->age));
        }
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->age, (void*)src->age, 8/*BLOCK_FIELD_IS_BYREF*/);}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->age, 8/*BLOCK_FIELD_IS_BYREF*/);}

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool;
        // __block修饰的变量，会对其进行包装 __Block_byref_age_0对象
        __attribute__((__blocks__(byref))) __Block_byref_age_0 age = {(void*)0,(__Block_byref_age_0 *)&age, 0, sizeof(__Block_byref_age_0), 10};
        void(*block)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, (__Block_byref_age_0 *)&age, 570425344));
        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);
        printf("age = %d\n",(age.__forwarding->age));

    }
    return 0;
}
static struct IMAGE_INFO { unsigned version; unsigned flag; } _OBJC_IMAGE_INFO = { 0, 2 };
```
由上可知
- __block修饰的age，变成了__Block_byref_age_0结构体变量。对age的调用都变成了age.__forwarding->age
- __block修饰后__main_block_desc_0结构体中通用会有copy和dispose两个方法

#### 6.__block修饰对象时
main.m代码    
```c
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Person *p = [[Person alloc] init];
        __block Person* weakPerson = p;
        void(^block)(void) = ^{
            NSLog(@"%@",weakPerson);
        };
        block();

    }
    return 0;
}

```
clang后代码
```c
struct __Block_byref_weakPerson_0 {
  void *__isa;
__Block_byref_weakPerson_0 *__forwarding;
 int __flags;
 int __size;
 void (*__Block_byref_id_object_copy)(void*, void*);
 void (*__Block_byref_id_object_dispose)(void*);
 Person *__strong weakPerson;
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  __Block_byref_weakPerson_0 *weakPerson; // by ref
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, __Block_byref_weakPerson_0 *_weakPerson, int flags=0) : weakPerson(_weakPerson->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  __Block_byref_weakPerson_0 *weakPerson = __cself->weakPerson; // bound by ref

            NSLog((NSString *)&__NSConstantStringImpl__var_folders_9r_tb39pygj2jq_9m64l9fjkyb80000gp_T_main_1b3fbf_mi_0,(weakPerson->__forwarding->weakPerson));
        }
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->weakPerson, (void*)src->weakPerson, 8/*BLOCK_FIELD_IS_BYREF*/);}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->weakPerson, 8/*BLOCK_FIELD_IS_BYREF*/);}

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        Person *p = ((Person *(*)(id, SEL))(void *)objc_msgSend)((id)((Person *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("Person"), sel_registerName("alloc")), sel_registerName("init"));
        __attribute__((__blocks__(byref))) __Block_byref_weakPerson_0 weakPerson = {(void*)0,(__Block_byref_weakPerson_0 *)&weakPerson, 33554432, sizeof(__Block_byref_weakPerson_0), __Block_byref_id_object_copy_131, __Block_byref_id_object_dispose_131, p};
        void(*block)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, (__Block_byref_weakPerson_0 *)&weakPerson, 570425344));
        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);

    }
    return 0;
}
static struct IMAGE_INFO { unsigned version; unsigned flag; } _OBJC_IMAGE_INFO = { 0, 2 };

```

```c
static void __Block_byref_id_object_copy_131(void *dst, void *src) {
 _Block_object_assign((char*)dst + 40, *(void * *) ((char*)src + 40), 131);
}
static void __Block_byref_id_object_dispose_131(void *src) {
 _Block_object_dispose(*(void * *) ((char*)src + 40), 131);
}
```

由此可知
- __block修饰的对象，在__Block_byref_weakPerson_0结构体内部会自动添加__Block_byref_id_object_copy和__Block_byref_id_object_dispose对被__block包装成结构体的对象进行内存管理
- 当block在栈上的时候，不会对__block变量产生内部内存管理。
- 当被copy到堆上的时候，会调用Block上的_Block_object_assign，内部会调用__Block_byref_id_object_copy_131，
- block移除的时候会调用dispose，__main_block_dispose_0，内部会调用__Block_byref_id_object_dispose_131