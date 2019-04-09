## Class的本质

不管是类对象还是元类对象，类型都是class，它们的底层都是objc_class结构体的指针
在clang后，找到底层代码中
```C
struct objc_class {
    Class _Nonnull isa __attribute__((deprecated));
} __attribute__((unavailable));

```
其实在老版本中代码会如下
```C
struct objc_class {
    Class _Nonnull isa  OBJC_ISA_AVAILABILITY;

#if !__OBJC2__
    Class _Nullable super_class                              OBJC2_UNAVAILABLE;
    const char * _Nonnull name                               OBJC2_UNAVAILABLE;
    long version                                             OBJC2_UNAVAILABLE;
    long info                                                OBJC2_UNAVAILABLE;
    long instance_size                                       OBJC2_UNAVAILABLE;
    struct objc_ivar_list * _Nullable ivars                  OBJC2_UNAVAILABLE;
    struct objc_method_list * _Nullable * _Nullable methodLists                    OBJC2_UNAVAILABLE;
    struct objc_cache * _Nonnull cache                       OBJC2_UNAVAILABLE;
    struct objc_protocol_list * _Nullable protocols          OBJC2_UNAVAILABLE;
#endif

} OBJC2_UNAVAILABLE;
/* Use `Class` instead of `struct objc_class *` */
```
已经标注为OBJC2_UNAVAILABLE，说明这些中间的代码已经没多大的用处了。
那么目前objc_class的结构是什么样的呢？ 我们可以通过在官网下载最新的objc最新的代码
objc_class主要代码如下
```c
struct objc_class : objc_object {
    // Class ISA;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // 用于具体获取类的信息

    class_rw_t *data() { 
        return bits.data();
    }
    void setData(class_rw_t *newData) {
        bits.setData(newData);
    }
```
可以发现objc_class集成objc_object。
objc_object中部分代码如下：
```c
struct objc_object {
private:
    isa_t isa;

public:

    // ISA() assumes this is NOT a tagged pointer object
    Class ISA();

    // getIsa() allows this to be a tagged pointer object
    Class getIsa();
```

发现objc_object中有一个isa指针，那么objc_class集成objc_object，所以同样有一个isa指针。

继续回到objc_class结构体，目光注意到下面代码
```C
  class_rw_t *data() { 
        return bits.data();
    }
    void setData(class_rw_t *newData) {
        bits.setData(newData);
    }
```
接着查看bits.data()方法
```C
class_rw_t* data() {
        return (class_rw_t *)(bits & FAST_DATA_MASK);
    }
    
// data pointer
#define FAST_DATA_MASK          0x00007ffffffffff8UL
```
bits&FAST_DATA_MASK相与，得到class_rw_t的地址。

接着探索class_rw_t结构体
部分代码如下：
```C
struct class_rw_t {
    uint32_t flags;
    uint32_t version;

    const class_ro_t *ro;

    //只是记录当前类的方法，属性，协议
    method_array_t methods; //方法列表
    property_array_t properties; //属性列表
    protocol_array_t protocols; //协议列表
```
继续探索class_ro_t结构体
部分代码如下：
```c
struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
#ifdef __LP64__
    uint32_t reserved;
#endif

    const uint8_t * ivarLayout;
    
    const char * name; //类名
    method_list_t * baseMethodList;
    protocol_list_t * baseProtocols;
    const ivar_list_t * ivars; //成员变量

    const uint8_t * weakIvarLayout;
    property_list_t *baseProperties;

    method_list_t *baseMethods() const {
        return baseMethodList;
    }
};
``` 

clang一个对象文件时，在cpp文件中都能找到最底层objc_class的结构组成
```C
struct _class_t {
	struct _class_t *isa;
	struct _class_t *superclass;
	void *cache;
	void *vtable;
	struct _class_ro_t *ro;
};

struct _class_ro_t {
	unsigned int flags;
	unsigned int instanceStart;
	unsigned int instanceSize;
	const unsigned char *ivarLayout;
	const char *name;
	const struct _method_list_t *baseMethods;
	const struct _objc_protocol_list *baseProtocols;
	const struct _ivar_list_t *ivars;
	const unsigned char *weakIvarLayout;
	const struct _prop_list_t *properties;
};
```
    


