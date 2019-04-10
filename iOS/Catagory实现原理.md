# Category实现原理
在objc-runtime-new.h文件中，可以找到category_t结构体的定义

```C
struct category_t {
    const char *name; //类名
    classref_t cls; //关联本类的指针
    struct method_list_t *instanceMethods;  //实例方法
    struct method_list_t *classMethods; // 类方法
    struct protocol_list_t *protocols; // 协议
    struct property_list_t *instanceProperties; // 属性

    method_list_t *methodsForMeta(bool isMeta) {
        if (isMeta) return classMethods;
        else return instanceMethods;
    }

    property_list_t *propertiesForMeta(bool isMeta) {
        if (isMeta) return nil; // classProperties;
        else return instanceProperties;
    }
};
```
从源码可以看出，category_t只包含对象方法，类方法，协议，属性的对应存储方式。并且我们发现类结构体中是不存在成员变量的，因此分类是不允许添加成员变量。分类中添加的属性并不会帮助我们自动生成成员变量。只会有get set方法的声明，需要我们自己去实现。
<br>
那么他们又是如何添加存储在类对象中的呢？
写一段简单的代码
```C
@interface Person : NSObject
{
@public
    int _age;
}
@property (nonatomic, assign) int height;
- (void)personMethod;
+ (void)personClassMethod;
@end

@implementation Person
- (void)personMethod {}
+ (void)personClassMethod {}
@end

扩展
@interface Person (test)
- (void)test;
+ (void)abc;
@property (assign, nonatomic) int age;
- (void)setAge:(int)age;
- (int)age;
@end

@implementation Person (test) 
- (void)test
{
}

+ (void)abc
{
}
- (void)setAge:(int)age
{
}
- (int)age
{
    return 10;
}
@end
```

首先通过命令行将Person+test.m文件转成为c++
```C
xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc -fobjc-arc -fobjc-runtime=ios-8.0.0 Person+test.m
```
打开cpp文件，找到对应的_category_t结构体
```c
struct _category_t {
	const char *name;
	struct _class_t *cls;
	const struct _method_list_t *instance_methods;
	const struct _method_list_t *class_methods;
	const struct _protocol_list_t *protocols;
	const struct _prop_list_t *properties;
};
```
紧接着看到_method_list_t结构体
```C
static struct /*_method_list_t*/ {
	unsigned int entsize;  // sizeof(struct _objc_method)
	unsigned int method_count;
	struct _objc_method method_list[3];
} _OBJC_$_CATEGORY_INSTANCE_METHODS_Person_$_test __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_objc_method),
	3,
	{{(struct objc_selector *)"test", "v16@0:8", (void *)_I_Person_test_test},
	{(struct objc_selector *)"setAge:", "v20@0:8i16", (void *)_I_Person_test_setAge_},
	{(struct objc_selector *)"age", "i16@0:8", (void *)_I_Person_test_age}}
};
```
上述_OBJC_$_CATEGORY_INSTANCE_METHODS_Person_$_test进行初始化，从名字看出，此对象为实例方法的实现

接下来会发现同样的_method_list_t，
```C
static struct /*_method_list_t*/ {
	unsigned int entsize;  // sizeof(struct _objc_method)
	unsigned int method_count;
	struct _objc_method method_list[1];
} _OBJC_$_CATEGORY_CLASS_METHODS_Person_$_test __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_objc_method),
	1,
	{{(struct objc_selector *)"abc", "v16@0:8", (void *)_C_Person_test_abc}}
};
```
上述_OBJC_$_CATEGORY_CLASS_METHODS_Person_$_test进行初始化，从名字可以看出此对象为类方法的实现
<br>
最后我们发现属性列表的实现

```C
static struct /*_prop_list_t*/ {
	unsigned int entsize;  // sizeof(struct _prop_t)
	unsigned int count_of_properties;
	struct _prop_t prop_list[1];
} _OBJC_$_PROP_LIST_Person_$_test __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_prop_t),
	1,
	{{"age","Ti,N"}}
};
```

再接下去可以看到_OBJC_$_CATEGORY_Person_$_test结构体
```C
static struct _category_t _OBJC_$_CATEGORY_Person_$_test __attribute__ ((used, section ("__DATA,__objc_const"))) = 
{
	"Person",
	0, // &OBJC_CLASS_$_Person,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_INSTANCE_METHODS_Person_$_test,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_CLASS_METHODS_Person_$_test,
	0,
	(const struct _prop_list_t *)&_OBJC_$_PROP_LIST_Person_$_test,
};
```

与_category_t结构体一一对应上，实现了具体的赋值
最后发现静态方法OBJC_CATEGORY_SETUP_$_Person_$_test

```C
static void OBJC_CATEGORY_SETUP_$_Person_$_test(void ) {
	_OBJC_$_CATEGORY_Person_$_test.cls = &OBJC_CLASS_$_Person;
}
__declspec(allocate(".objc_inithooks$B")) static void *OBJC_CATEGORY_SETUP[] = {
	(void *)&OBJC_CATEGORY_SETUP_$_Person_$_test,
};
```

最后将_OBJC_$_CATEGORY_Preson_$_Test的cls指针指向OBJC_CLASS_$_Preson结构体地址。我们这里可以看出，cls指针指向的应该是分类的主类类对象的地址。
此方法最后赢应该是在objc_inithooks的时候调用
<br>
通过以上分析我们发现，分类源码中确实是将我们定义的对象方法，类方法，属性等存放在catagory_t结构体中。
接下来我们在回到runtime源码查看catagory_t是如何存储在类对象中的。
首先来到runtime初始化函数，源码在objc-os.mm文件

```C
#if !__OBJC2__
static __attribute__((constructor))
#endif
void _objc_init(void)
{
    static bool initialized = false;
    if (initialized) return;
    initialized = true;
    
    // fixme defer initialization until an objc-using image is found?
    environ_init();
    tls_init();
    static_init();
    lock_init();
    exception_init();
        
    // Register for unmap first, in case some +load unmaps something
    _dyld_register_func_for_remove_image(&unmap_image);
    dyld_register_image_state_change_handler(dyld_image_state_bound,
                                             1/*batch*/, &map_2_images);
    dyld_register_image_state_change_handler(dyld_image_state_dependents_initialized, 0/*not batch*/, &load_images);
}
```

点击进入map_2_images（images代表模块）函数，再进入map_images_nolock函数，并且在此函数最后找到_read_images函数，最终找到加载category相关的代码。

```C
    // Discover categories. 
    for (EACH_HEADER) {
        category_t **catlist = 
            _getObjc2CategoryList(hi, &count);
        for (i = 0; i < count; i++) {
            category_t *cat = catlist[i];
            Class cls = remapClass(cat->cls);

            if (!cls) {
                // Category's target class is missing (probably weak-linked).
                // Disavow any knowledge of this category.
                catlist[i] = nil;
                if (PrintConnecting) {
                    _objc_inform("CLASS: IGNORING category \?\?\?(%s) %p with "
                                 "missing weak-linked target class", 
                                 cat->name, cat);
                }
                continue;
            }

            // Process this category. 
            // First, register the category with its target class. 
            // Then, rebuild the class's method lists (etc) if 
            // the class is realized. 
            bool classExists = NO;
            if (cat->instanceMethods ||  cat->protocols  
                ||  cat->instanceProperties) 
            {
                addUnattachedCategoryForClass(cat, cls, hi);
                if (cls->isRealized()) {
                    remethodizeClass(cls);
                    classExists = YES;
                }
                if (PrintConnecting) {
                    _objc_inform("CLASS: found category -%s(%s) %s", 
                                 cls->nameForLogging(), cat->name, 
                                 classExists ? "on existing class" : "");
                }
            }

            if (cat->classMethods  ||  cat->protocols  
                /* ||  cat->classProperties */) 
            {
                addUnattachedCategoryForClass(cat, cls->ISA(), hi);
                if (cls->ISA()->isRealized()) {
                    remethodizeClass(cls->ISA());
                }
                if (PrintConnecting) {
                    _objc_inform("CLASS: found category +%s(%s)", 
                                 cls->nameForLogging(), cat->name);
                }
            }
        }
    }

    ts.log("IMAGE TIMES: discover categories");
```

从这段代码可以看出，是用来查找有没有分类的，通过_getObjc2CategoryList获取分类列表，进行遍历，获取其中的实例方法，属性，协议，类方法。最终都调用了remethodizeClass函数，进入内部查看

```C
static void remethodizeClass(Class cls)
{
    category_list *cats;
    bool isMeta;

    runtimeLock.assertWriting();

    isMeta = cls->isMetaClass();

    // Re-methodizing: check for more categories
    if ((cats = unattachedCategoriesForClass(cls, false/*not realizing*/))) {
        if (PrintConnecting) {
            _objc_inform("CLASS: attaching categories to class '%s' %s", 
                         cls->nameForLogging(), isMeta ? "(meta)" : "");
        }
        
        attachCategories(cls, cats, true /*flush caches*/);        
        free(cats);
    }
}

```

通过代码发现attachCategories函数接受了cls对象，分类数组cats，一个对象可以对应多个分类。我们继续查看attachCategories函数内部实现

```C
static void 
attachCategories(Class cls, category_list *cats, bool flush_caches)
{
    if (!cats) return;
    if (PrintReplacedMethods) printReplacements(cls, cats);

    bool isMeta = cls->isMetaClass();

    // fixme rearrange to remove these intermediate allocations
    
    // 根据分类列表，给方法列表，属性列表，协议列表分配内存
    method_list_t **mlists = (method_list_t **)
        malloc(cats->count * sizeof(*mlists));
    property_list_t **proplists = (property_list_t **)
        malloc(cats->count * sizeof(*proplists));
    protocol_list_t **protolists = (protocol_list_t **)
        malloc(cats->count * sizeof(*protolists));

    // Count backwards through cats to get newest categories first
    int mcount = 0;
    int propcount = 0;
    int protocount = 0;
    int i = cats->count;
    bool fromBundle = NO;
    while (i--) {
            //遍历拿到每一个分类
        auto& entry = cats->list[i];
        //将每一个分类的方法添加到分配的mlists中
        method_list_t *mlist = entry.cat->methodsForMeta(isMeta);
        if (mlist) {
            mlists[mcount++] = mlist;
            fromBundle |= entry.hi->isBundle();
        }
         //将每一个分类的协议添加到分配的protolists中
        property_list_t *proplist = entry.cat->propertiesForMeta(isMeta);
        if (proplist) {
            proplists[propcount++] = proplist;
        }
         //将每一个分类的属性添加到分配的proplists中
        protocol_list_t *protolist = entry.cat->protocols;
        if (protolist) {
            protolists[protocount++] = protolist;
        }
    }

    //获取类对象中class_rw_t对象，此对象前面介绍过，是用来存储实例方法，属性，协议的
    auto rw = cls->data();

    //然后将分类中的方法列表，添加到类对象的methods数组中
    prepareMethodLists(cls, mlists, mcount, NO, fromBundle);
    rw->methods.attachLists(mlists, mcount);
    free(mlists);
    if (flush_caches  &&  mcount > 0) flushCaches(cls);
    
    //然后将分类中的属性列表，添加到类对象的properties数组中
    rw->properties.attachLists(proplists, propcount);
    free(proplists);
    
    //然后将分类中的协议列表，添加到类对象的protocols数组中
    rw->protocols.attachLists(protolists, protocount);
    free(protolists);
}

```

从上述代码可以看出，将分类中的属性，协议，方法列表，malloc分配好对应的内存，然后在分类的这些东西添加到对应的类对象的class_rw_t对象中。将分类和类对象本身进行合并。
<br>
接下来继续查看attachLists函数

```c
void attachLists(List* const * addedLists, uint32_t addedCount) {
        if (addedCount == 0) return;

        if (hasArray()) {
            // many lists -> many lists
            uint32_t oldCount = array()->count;
            uint32_t newCount = oldCount + addedCount;
            //重新分配内存
            setArray((array_t *)realloc(array(), array_t::byteSize(newCount)));
            //改变当前array的大小
            array()->count = newCount;
            //array()->lists 表示类对象本身的list列表
            //将老方法列表的内存移动到新分配内存的后半段
            memmove(array()->lists + addedCount, array()->lists, 
                    oldCount * sizeof(array()->lists[0]));
            //将category的方法拷贝到当前lists列表中
            memcpy(array()->lists, addedLists, 
                   addedCount * sizeof(array()->lists[0]));
        }
        else if (!list  &&  addedCount == 1) {
            // 0 lists -> 1 list
            list = addedLists[0];
        } 
        else {
            // 1 list -> many lists
            List* oldList = list;
            uint32_t oldCount = oldList ? 1 : 0;
            uint32_t newCount = oldCount + addedCount;
            setArray((array_t *)malloc(array_t::byteSize(newCount)));
            array()->count = newCount;
            if (oldList) array()->lists[addedCount] = oldList;
            memcpy(array()->lists, addedLists, 
                   addedCount * sizeof(array()->lists[0]));
        }
    }
```

**array()->lists：类对象原来的方法列表，属性列表，协议列表
addedLists：分类的方法列表，属性列表，协议列表**
<br>
经过memmove,将类本身列表的内存地址往后移。
memcpy后，内存的分别情况如下
![](/Users/user/Blogs/iOS/images/1554882236944.jpg)
我们发现原来指针并没有改变，至始至终指向开头的位置。并且经过memmove和memcpy方法之后，分类的方法，属性，协议列表被放在了类对象中原本存储的方法，属性，协议列表前面。
那么为什么要将分类方法的列表追加到本来的对象方法前面呢，这样做的目的是为了保证分类方法优先调用，我们知道当分类重写本类的方法时，会覆盖本类的方法。
其实经过上面的分析我们知道本质上并不是覆盖，而是优先调用。本类的方法依然在内存中的。

我们可以进行测试，看类中的方法是不是依然存在？

```C
 Person *p = [[Person alloc] init];
        [p run];
        
        //打印类的方法列表
        unsigned int count;
        Method *methodList = class_copyMethodList([Person class], &count);
        NSMutableString *methodNames = [NSMutableString string];
        //变量方法列表
        for (int i = 0; i < count; i++) {
            // 获得方法
            Method method = methodList[i];
            // 获得方法名
            NSString *name = NSStringFromSelector(method_getName(method));
            // 拼接方法
            [methodNames appendString:name];
            [methodNames appendString:@", "];
        }
        
        NSLog(@"%@",methodNames);
        
    // Person (Test2) - run
    // ersonMethod, run, run, height, setHeight:, test, age, setAge:,    
```

有结果可知，发现打印中的结果有两个run方法名。

**总结：**
Category的实现原理，以及Category为什么只能加方法不能加属性?
答：分类的实现原理是将category中的方法，属性，协议数据放在category_t结构体中，然后将结构体内的方法列表拷贝到类对象的方法列表中。
Category可以添加属性，但是并不会自动生成成员变量及set/get方法。因为category_t结构体中并不存在成员变量。通过之前对对象的分析我们知道成员变量是存放在实例对象中的，并且编译的那一刻就已经决定好了。而分类是在运行时才去加载的。那么我们就无法再程序运行时将分类的成员变量中添加到实例对象的结构体中。因此分类中不可以添加成员变量。

#### load 和 initialize
load方法会在程序启动就会调用，当装载类信息的时候就会调用。
再次回到_objc_init函数中
```C
void _objc_init(void)
{
    static bool initialized = false;
    if (initialized) return;
    initialized = true;
    
    // fixme defer initialization until an objc-using image is found?
    environ_init();
    tls_init();
    static_init();
    lock_init();
    exception_init();
        
    // Register for unmap first, in case some +load unmaps something
    _dyld_register_func_for_remove_image(&unmap_image);
    dyld_register_image_state_change_handler(dyld_image_state_bound,
                                             1/*batch*/, &map_2_images);
    dyld_register_image_state_change_handler(dyld_image_state_dependents_initialized, 0/*not batch*/, &load_images);
}
```
找到load_images函数进入，再找到call_load_methods函数进入
```c
void call_load_methods(void)
{
    static bool loading = NO;
    bool more_categories;

    loadMethodLock.assertLocked();

    // Re-entrant calls do nothing; the outermost call will finish the job.
    if (loading) return;
    loading = YES;

    void *pool = objc_autoreleasePoolPush();

    do {
        // 1. Repeatedly call class +loads until there aren't any more
        while (loadable_classes_used > 0) {
            // 先调用类的load方法
            call_class_loads();
        }

        // 2. Call category +loads ONCE
        //再调用分类的loads方法
        more_categories = call_category_loads();

        // 3. Run more +loads if there are classes OR more untried categories
    } while (loadable_classes_used > 0  ||  more_categories);

    objc_autoreleasePoolPop(pool);

    loading = NO;
}
```
通过源码我们发现是优先调用类的load方法，之后调用分类的load方法。
通过代码验证，可以发现
```C
Person load
Person+test load
```
确实是优先调用类的load方法之后调用分类的load方法，不过调用类的load方法之前会保证其父类已经调用过load方法。

继续查看call_class_loads方法实现
```C
static void call_class_loads(void)
{
    int i;
    
    // Detach current loadable list.
    struct loadable_class *classes = loadable_classes;
    int used = loadable_classes_used;
    loadable_classes = nil;
    loadable_classes_allocated = 0;
    loadable_classes_used = 0;
    
    // Call all +loads for the detached list.
    for (i = 0; i < used; i++) {
        Class cls = classes[i].cls;
        load_method_t load_method = (load_method_t)classes[i].method;
        if (!cls) continue; 

        if (PrintLoading) {
            _objc_inform("LOAD: +[%s load]\n", cls->nameForLogging());
        }
        (*load_method)(cls, SEL_load);
    }
    
    // Destroy the detached list.
    if (classes) free(classes);
}

```
可以发现，调用load方法是直接拿到load方法的内存地址直接调用（(*load_method)(cls, SEL_load);），不是通过发送消息机制调用

<br>
查看initialize源码，在objc_initialize.mm文件中

```c
void _class_initialize(Class cls)
{
    ...
            ((void(*)(Class, SEL))objc_msgSend)(cls, SEL_initialize);

    ...
}
```

initialize是通过消息发送机制调用的，消息发送机制通过isa指针找到对应的方法与实现，因此先找到分类方法中的实现，会优先调用分类方法中的实现。
通过代码验证，,Person，Person+test中都实现initialize方法，可以发现

```c
Person+test initialize
```

最后会调用分类中的initialize方法

**总结：**
问：Category中有load方法吗？load方法是什么时候调用的？load 方法能继承吗？
答：Category中有load方法，load方法在程序启动装载类信息的时候就会调用。load方法可以继承。调用子类的load方法之前，会先调用父类的load方法
问：load、initialize的区别，以及它们在category重写的时候的调用的次序。
答：区别在于调用方式和调用时刻
调用方式：load是根据函数地址直接调用，initialize是通过objc_msgSend调用
调用时刻：load是runtime加载类、分类的时候调用（只会调用1次），initialize是类第一次接收到消息的时候调用，每一个类只会initialize一次（父类的initialize方法可能会被调用多次）
调用顺序：先调用类的load方法，先编译那个类，就先调用load。在调用load之前会先调用父类的load方法。分类中load方法不会覆盖本类的load方法，先编译的分类优先调用load方法。initialize先初始化父类，之后再初始化子类。如果子类没有实现+initialize，会调用父类的+initialize（所以父类的+initialize可能会被调用多次），如果分类实现了+initialize，就覆盖类本身的+initialize调用。