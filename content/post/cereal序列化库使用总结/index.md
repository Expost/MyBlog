---
title: cereal序列化库使用总结
date: 2019-11-23 10:31:54
categories: [C++,序列化]
---

近段有对C++对象序列化的需求，因此了解了一下C++的序列化库，网上搜到的主要是protocolbuf和boost::serialization这两个。而这两者均不太满足自己的需求，protocolbuf是需要按照其规则定义好对象的结构，之后生成相应的序列化和反序列化代码，而自己需要对现有的部分C++代码中的对象进行序列化，如果要使用protocolbuf，成本太高。boolst::serialization库实际上是满足需求的，只是它的代码太多了，不想因为这个简单的需求带上那么多的代码。

最终又经过一番查找，找到了[cereal](https://github.com/USCiLab/cereal)这个库，[官方文档](http://uscilab.github.io/cereal/)也是比较详细，初步了解后确认其满足需求，而在使用过程中遇到了一些问题，因此这里总结下，以便回顾。

## cereal基本介绍

根据官方文档介绍，cereal是一个只有头文件的C++序列化库，它能够将任何数据类型转换为二进制编码或是xml文件或是json文件，也可以将转换后的文件恢复成原来的数据结构。cereal被设计为快速、轻量和易于扩展的，同时其不依赖任何其他第三方库，因此可以非常容易被已有的工程所使用。

概括来说，其主要有这些特点：

1. cereal使用了C++11的新功能，因此需要支持C++11的编译器才能够编译使用。
2. cereal的性能很高，它通常比boost的serialization库更快，同时产生的二进制文件却更小。
3. cereal支持多态和继承，不支持原生指针，但可以使用智能指针，如std::shared_ptr和std::unique_ptr。
3. cereal支持将C++对象序列化为二进制、xml、json文件，如果希望支持其他的文件类型，cereal的代码结构也可以很容易的让你进行扩展。
5. cereal非常易于使用，它完全由头文件实现，不依赖第三方库，文档很完善。同时增加了很多静态检查，以便于将错误提前暴露至编译期。
4. cereal的代码经过了单元测试的检验，质量可靠。
6. cereal的语法规则与boost的serialization类似，因此可以对先前使用过boost::serialization库的人来说将会很容易理解。
7. BSD协议，协议友好。

## 使用

### 基本用法

下面是对官方例子的一个简单修改，程序使用vs2015编译通过（注，后面的所有例子均使用vs2015编译）。

```C++
#include "cereal/types/unordered_map.hpp"
#include "cereal/types/memory.hpp"
#include "cereal/types/string.hpp"
#include "cereal/archives/portable_binary.hpp"
#include "cereal/archives/binary.hpp"
#include "cereal/archives/xml.hpp"
#include "cereal/archives/json.hpp"
#include "cereal/access.hpp"
#include <fstream>
using namespace std;

struct MyRecord
{
    // 这里的数据都是基本数据类型
    // 注意string需要包含cereal对应的头文件
    uint8_t x;
    string y;
    float z;
};

// 这里使用serialize方法进行序列化MyRecord类，该函数可实现在函数外，也可实现在函数内
// 除了serialize方法外，还有save和load方法分别用来序列化和反序列化，
// 一般来说优先使用只需实现一个的serialize方法
template <class Archive>
void serialize(Archive & ar, MyRecord& m)
{
    ar(m.x, m.y, m.z);
}

class SomeData
{
public:
    SomeData() = default;
    ~SomeData() = default;

    void gen_data()
    {
        id_ = 100;
        data_ = std::make_shared<std::unordered_map<uint32_t, std::shared_ptr<MyRecord>>>();

        for (int i = 0; i < id_; i++)
        {
            (*data_)[i] = make_shared<MyRecord>();

            (*data_)[i]->x = i;
            (*data_)[i]->y = to_string(i + 1);
            (*data_)[i]->z = i + 2;
        }
    }

    void show()
    {
        printf("id %d\n", id_);
        for (auto &itr : *data_)
        {
            printf("key %d, x %d, y %s, z %f\n", itr.first, itr.second->x, itr.second->y.c_str(), itr.second->z);
        }
    }

private:
    // 这里使用save和load方法实现对象的序列化及反序列化
    // save和load方法可以设置为私有，但设置为私有后需要设置cereal::access类为该类的友元
    friend class cereal::access;
    template <class Archive>
    void save(Archive & ar) const
    {
        ar(id_, data_);
    }

    template <class Archive>
    void load(Archive & ar)
    {
        ar(id_, data_);
    }

private:
    int32_t id_;
    // cereal不支持原生指针，但支持智能指针
    std::shared_ptr<std::unordered_map<uint32_t, std::shared_ptr<MyRecord>>> data_;
};

int main()
{
    // 注意，cereal的Archive使用了RAII，Archive在析构时才保证数据由缓存写入到文件
    // 因此，使用大括号确保archive对象在离开作用域后执行析构函数，从而将数据flush
    {
        SomeData some_data;
        some_data.gen_data();

        // 这里生成二进制数据
        std::ofstream os("out.cereal", std::ios::binary);
        cereal::BinaryOutputArchive archive(os);

        // 若要序列为xml，调整为XMLOutputArchive即可，json同理
        //std::ofstream os("data.xml");
        //cereal::XMLOutputArchive archive(os);

        archive(some_data);
    }
    
    {
        SomeData some_data;
        // 对刚刚序列化生成的out.cereal文件进行反序列化
        std::ifstream os("out.cereal", std::ios::binary);
        cereal::BinaryInputArchive archive(os);

        // 若要反序列为xml，调整为XMLInputArchive即可，json同理
        //std::ifstream os("data.xml");
        //cereal::XMLInputArchive archive(os);

        archive(some_data);
        some_data.show();
    }

    getchar();
    return 0;
}
```

上面程序是一个简单的例子，通过这个例子便可大致清楚cereal的用法。cereal支持对常见的标准库容器进行序列化，在上面的代码中就对string和unordered_map直接进行了序列化，**但要注意，对标准库容器进行序列化之前一定要包含cereal对应的头文件（在types目录下）**，否则会编译失败，提示`cereal could not find any output serialization functions for the provided type and archive combination.`，先前使用时由于没有注意到这点，定位了好久，一直以为是自己用法问题😓。

这个错误主要得益于cereal提供的良好的静态检查，如果把上面`MyRecord`类的`serialize`函数删掉，那么在编译时也会提示这个错误。通过静态检查，将运行时发生的错误提前暴露在了编译期。不过这个错误的蛋疼点在于只是提示你没有找到对应的序列化函数，但却没有提示是哪个类缺少序列化函数。

以上只是一个最简单的例子，但在实际开发中，类的实现未必会这么简单，还会遇到类没有默认构造函数、类之间有继承、多态等行为的情况。下面说下这几种情况的处理。

### 无默认构造函数

最开始看文档时，有看到文档专门说明无默认构造函数时该如何处理，当时并未在意，没有get到序列化与构造函数间有什么关系。随着后来的使用，才逐渐明白构造函数确实与序列化没啥关系，但是和反序列化有关。在反序列化时，cereal需要先创建一个对应的对象，之后再根据实现的反序列化函数填充对象的值。如果这个类没有默认构造函数，那么cereal便不能直接构造这个对象，因此需要对没有默认构造函数的类单独处理，以便cereal可以正确的创建的对象。

在cereal中，这个单独处理的操作便是`load_and_construct`函数。官方文档的[指针引用部分](http://uscilab.github.io/cereal/pointers)说明了在没有默认构造函数时该如何处理，下面是相关的示例代码。

```C++
#include "cereal/types/memory.hpp"
#include "cereal/types/vector.hpp"
#include "cereal/archives/binary.hpp"
#include "cereal/access.hpp"
#include <fstream>
using namespace std;

class MyType
{
public:
    // 这里只用写save方法进行序列化
    // 反序列化使用下面的load_and_construct方法
    template <class Archive>
    void save(Archive & ar) const
    {
        ar(x_, y_);
    }

    // 注意设置cereal::access为友元类，否则无法访问私有的构造函数
    friend class cereal::access;
    // 实现load_and_construct方法，注意是static的
    template <class Archive>
    static void load_and_construct(Archive & ar, cereal::construct<MyType> & construct)
    {
        // 这里先创建两个临时变量进行反序列化
        int x, y;
        ar(x, y);
        // 使用x用来创建对象
        construct(x);
        // 将临时变量y赋给创建对象的成员变量y_
        construct->y_ = y;
    }

public:
    void set_y(const int y) { y_ = y;}
    int get_x() const{ return x_;}
    int get_y() const{return y_;}

public:
    static shared_ptr<MyType> create_type(int x)
    {
        return shared_ptr<MyType>(new MyType{ x });
    }

private:
    MyType(int x) :x_(x), y_(0) {}

private:
    int x_;
    int y_;
};

int main()
{
    {
        // 不能直接写类型，要使用指针，因为MyType没有默认构造函数，在反序列化创建对象时会报错
        // vector<MyType> v;

        vector<std::shared_ptr<MyType>> v;
        v.push_back(MyType::create_type(1));
        v.push_back(MyType::create_type(2));
        v.push_back(MyType::create_type(3));
        v[0]->set_y(10);
        v[1]->set_y(20);
        v[2]->set_y(30);

        // 这里生成二进制数据
        std::ofstream os("out.cereal", std::ios::binary);
        cereal::BinaryOutputArchive archive(os);
    
        for (const auto &itr : v)
        {
            printf("%d %d\n", itr->get_x(), itr->get_y());
        }

        archive(v);
    }
    printf("================================\n");
    {
        vector<std::shared_ptr<MyType>> v;

        // 对刚刚序列化生成的out.cereal文件进行反序列化
        std::ifstream os("out.cereal", std::ios::binary);
        cereal::BinaryInputArchive archive(os);
    
        archive(v);
        for (const auto &itr : v)
        {
            printf("%d %d\n", itr->get_x(), itr->get_y());
        }
    }

    getchar();
    return 0;
}
```

在上面的例子中，使用`save`函数用来序列化，而对于反序列化，没有使用`load`函数，而是使用了`load_and_construct`函数，从它的名字可以看到 *加载* 和 *构造* 的含义。由于`MyType`类没有默认的构造函数，因此需要特殊处理，通过`load_and_construct`函数来用特殊的方法构造。这里要注意一点，由于该类的构造函数还是私有的，所以需要将`cereal::access`类设为该类的友元，以便在`load_and_construct`函数中调用该类的构造函数。

在`load_and_construct`函数中，通过传入的`construct`参数进行对象的构造，在构造前需要先将对象的成员进行反序列化，反序列化后得到`x_`和`y_`的值，其中`x_`变量在构造时由参数指定，因此直接使用`construct`进行构造即可。而`y_`变量在构造时默认设为0，需要后面通过`set_y`函数进行设置，在这里，可以直接通过`construct`访问`MyType`类对象的各个成员，因此直接将`y`值赋给`construct->y_`即可。

`construct->`的用法参考自[github issue 237](https://github.com/USCiLab/cereal/issues/237#issuecomment-144538466)。

### 继承

继承在类关系中也很常用，这里的关注点主要是在对子类进行正反序列化时，如何方便简单的对父类的成员变量进行正反序列化。cereal提供了`cereal::base_class<BaseT>( this )`方法可以快速的对父类的成员变量进行正反序列化。

[官方文档](http://uscilab.github.io/cereal/inheritance.html)中专门有一节说明如何处理继承时的正反序列化问题，下面是相关的示例代码。

```C++
#include "cereal/types/memory.hpp"
#include "cereal/types/vector.hpp"
#include "cereal/types/base_class.hpp"
#include "cereal/archives/binary.hpp"
#include "cereal/access.hpp"
#include <fstream>
using namespace std;

class A
{
public:
    A() :a_(0), is_set_(false) {}
    int get_a() const { return a_; }
    bool get_bool() const { return is_set_; }
    void set_a(int a) { a_ = a; is_set_ = true; }

    template <class Archive>
    void serialize(Archive &ar)
    {
        ar(a_, is_set_);
    }

private:
    int a_;
    bool is_set_;       //< is_set_是一个完全的内部成员，不对外暴露任何可设置的途径
};

class B
{
public:
    B() :b_(0) {}
    int get_b() const { return b_; }
    void set_b(int b) { b_ = b; }

    template<class Archive>
    void serialize(Archive &ar)
    {
        ar(b_);
    }

private:
    int b_;
};

// 类C分别继承自A类和B类
class C :public A, public B
{
public:
    C(int c) : c_(c) {}
    int get_c() const { return c_; }
    void set_c(int c) { c_ = c; }

    template<class Archive>
    void serialize(Archive &ar)
    {
        // 注意这里的序列化顺序，先序列化C类的成员，之后序列化A和B的
        // 如果继承自多个类，那么依次序列化每个类即可
        ar(c_, cereal::base_class<A>(this), cereal::base_class<B>(this));
    }

    template<class Archive>
    static void load_and_construct(Archive & ar, cereal::construct<C> & construct)
    {
        // 先反序列化C类的成员，之后调用构造函数创建对象
        // 如果先序列化了A和B，由于对象没有创建，这里不方便进行反序列化
        int c;
        ar(c);
        construct(c);
        
        // 对C类继承的A类成员和B类成员进行反序列化
        ar(cereal::base_class<A>(construct.ptr()), cereal::base_class<B>(construct.ptr()));
    }

private:
    int c_;
};

int main()
{
    {
        auto c = make_unique<C>(0);
        c->set_a(10);
        c->set_b(20);
        c->set_c(30);

        // 这里生成二进制数据
        std::ofstream os("out.cereal", std::ios::binary);
        cereal::BinaryOutputArchive archive(os);

        int a_ = c->get_a();
        int b_ = c->get_b();
        int c_ = c->get_c();
        bool is_set_ = c->get_bool();
        printf("%d %d %d %d\n", a_, b_, c_, is_set_);
        archive(c);
    }
    printf("================================\n");
    {
        auto c = make_unique<C>(0);

        // 对刚刚序列化生成的out.cereal文件进行反序列化
        std::ifstream os("out.cereal", std::ios::binary);
        cereal::BinaryInputArchive archive(os);
    
        archive(c);
        int a_ = c->get_a();
        int b_ = c->get_b();
        int c_ = c->get_c();
        bool is_set_ = c->get_bool();
        printf("%d %d %d %d\n", a_, b_, c_, is_set_);
    }

    getchar();
    return 0;
}
```

在上面的例子中，共有A、B、C这3个类，其中C类继承自A类和B类。在对C类进行序列化的时候，通过`cereal::base_class<BaseT>(this)`对A类和B类的成员变量进行序列化。但在序列化的时候，并没有按照A、B、C的这个顺序进行序列化。而是先序列化C的成员，之后再按照A、B的顺序进行序列化。这样做的原因在下面的反序列化说明中进行阐述。

在反序列化的时候，由于C类没有默认构造函数，因此需要通过`load_and_construct`函数调用对应的构造函数来创建对象，由于先前序列化时是先序列化了C类的成员，因此在反序列化时也就可以先反序列化C类的成员，并根据对应的参数来构造对象。如果使用的是A、B、C的顺序序列化，那在反序列化时，先反序列化A和B，由于这个时候对象还没有构造，因此就只能先使用临时变量存储A和B的成员，如果A和B的成员有很多，那这里就会很麻烦。

因此先反序列化C的成员，之后构造对象，在构造对象之后，通过`construct.ptr()`方法获取对象的`this`指针，之后再次使用`cereal::base_class<BaseT>`方法以及`this`指针便可快速对A和B的成员进行反序列化，不用再麻烦的使用临时变量存储A类和B类的成员。

实际上，在上面的代码中也只有使用上面这种方法进行反序列化。在上面的例子中，A类有个`is_set_`的变量，这个变量并未对外暴露任何的设置接口（A类对外提供了`set_a`接口用以设置`a_`的值，但没有接口设置`is_set_`的值），又因为`is_set_`变量是私有的，因此也无法通过`construct`直接访问`is_set_`。所以除了上面的方法外，据我目前了解，应该是没有办法反序列化A类的`is_set_`变量了。

这部分的内容同样参考自[github issue 237](https://github.com/USCiLab/cereal/issues/237#issuecomment-144549961)。

### 多态

这里的多态主要是指运行时多态，通过多态，可以使得程序在调用同一个接口的情况下获得不同的行为。比如下面这种情况。

```C++
class IFly
{
public:
    virtual void fly() = 0;
};

class Duck : public IFly
{
public:
    void fly() { cout << "duck fly." << endl; }
};

class Bird :public IFly
{
public:
    void fly() { cout << "bird fly." << endl; }
};

IFly *fly1 = new Duck{};
IFly *fly2 = new Bird{};

fly1->fly();    //< 这里输出 duck fly
fly2->fly();    //< 这里输出 bird fly
```

在上面的例子中，我们分别创建了`Duck`类实例和`Bird`类实例，并将他们都给到`IFly`接口指针，虽然接口相同，但在实际调用时，会有不同的行为。

设想有一个数组保存了很多实现了IFly接口的实例，对这个数组序列化时，序列化库该如何确定那个对象到底是什么呢？

cereal文档中有[一节](http://uscilab.github.io/cereal/polymorphism.html)介绍了多态问题的处理，它主要提供了两个宏来关联接口与实现接口的子类。具体参见下面代码（稍微有点复杂😥）。

```C++
#include "cereal/types/memory.hpp"
#include "cereal/types/vector.hpp"
#include "cereal/types/base_class.hpp"
#include "cereal/archives/binary.hpp"
#include "cereal/types/polymorphic.hpp"
#include "cereal/access.hpp"
#include <vector>
#include <fstream>
using namespace std;

enum class Type
{
    BIRD = 1,
    DUCK,
    NONE
};

class IFly
{
public:
    IFly(const Type t) :type_(t) {}

public:
    virtual void fly() = 0;

private:
    friend class cereal::access;
    template<class Archive>
    void serialize(Archive &ar)
    {
        ar(type_);
    }

    template<class Archive>
    static void load_and_construct(Archive & ar, cereal::construct<IFly> & construct)
    {
        Type t;
        ar(t);
        construct(t);
    }

protected:
    Type type_;
};

class Duck : public IFly
{
public:
    Duck(uint32_t id) : IFly(Type::DUCK), id_(id) {}
    void fly() { cout << "duck " << id_ << " is flying." << endl; }
    
private:
    friend class cereal::access;
    template<class Archive>
    void serialize(Archive &ar)
    {
        // 这里序列化了IFly基类
        ar(id_, cereal::base_class<IFly>(this));
    }

    template<class Archive>
    static void load_and_construct(Archive & ar, cereal::construct<Duck> & construct)
    {
        uint32_t id;
        ar(id);
        construct(id);
        // 对基类IFly进行反序列化
        ar(cereal::base_class<IFly>(construct.ptr()));
    }

protected:
    uint32_t id_;
};

// BlackDuck继承自Duck类
class BlackDuck : public Duck
{
public:
    BlackDuck(uint32_t id) : Duck(id) {}
    void fly() { cout << "black duck " << id_ << " is flying." << endl; }

    template<class Archive>
    void serialize(Archive &ar)
    {
        // BlackDuck没有成员变量，因此直接对父类进行序列化
        ar(cereal::base_class<Duck>(this));
    }

    template<class Archive>
    static void load_and_construct(Archive & ar, cereal::construct<BlackDuck> & construct)
    {
        // 随便填个值进行构造
        uint32_t id = 0;
        construct(id);
        // 对基类进行反序列化
        ar(cereal::base_class<Duck>(construct.ptr()));
    }
};

// 该类为模板类
template <typename T>
class Bird :public IFly
{
public:
    // 该类的构造为私有函数，通过EnableMakeShared类继承Bird类的方式以便于使用make_shared方法构造对象，该方法的参考链接见下方的说明
    // 这个类本应该是create方法的内部类，但那样的话就没法使用CEREAL_REGISTER_TYPE宏注册该类了
    // 为了序列化，无奈将该类改为了Bird类的内部类，且属性为public
    struct EnableMakeShared :public Bird<T>
    {
        template <typename...Args>
        EnableMakeShared(Args&&... args) :Bird(std::forward<Args>(args)...) {}

    private:
        // 由于创建的实际是EnableMakeShared实例，因此该实例也要实现正反序列化函数
        friend class cereal::access;
        template<class Archive>
        void serialize(Archive &ar)
        {
            ar(cereal::base_class<Bird<T>>(this));
        }

        template<class Archive>
        static void load_and_construct(Archive & ar, cereal::construct<EnableMakeShared> & construct)
        {
            uint32_t id;
            T data;
            ar(id, data);
            construct(id, data);
        }
    };

    // 静态方法，用于使用make_shared来创建私有构造的Bird类
    template <typename...Args>
    static std::shared_ptr<Bird<T>> create(Args&&... args)
    {
        return static_pointer_cast<Bird<T>>(make_shared<EnableMakeShared>(std::forward<Args>(args)...));
    }

public:
    void fly() { cout << "bird " << id_ << " is flying and data is " << data_ << endl; }

private:
    friend class cereal::access;
    template<class Archive>
    void serialize(Archive &ar)
    {
        // 由于子类有确定的类型，因此实际上没有必要对父类的type进行序列化
        ar(id_, data_);
    }

    template<class Archive>
    static void load_and_construct(Archive & ar, cereal::construct<Bird<T>> & construct)
    {
        // 同序列化，无需对父类的type进行反序列化
        uint32_t id;
        T data;
        ar(id, data);
        construct(id, data);
    }

private:
    // 构造函数是私有的
    Bird(uint32_t id, T data) :IFly(Type::BIRD), id_(id), data_(data) {}

private:
    uint32_t id_;
    T data_;
};

// 使用CEREAL_REGISTER_TYPE注册子类
CEREAL_REGISTER_TYPE(Duck);
CEREAL_REGISTER_TYPE(BlackDuck);
// 因为create方法实际上创建的是EnableMakeShared类，所以这里也需要注册EnableMakeShared类
// 由于Bird类是模板类，因此需要对不同的模板参数分别进行注册
CEREAL_REGISTER_TYPE(Bird<uint32_t>::EnableMakeShared);
CEREAL_REGISTER_TYPE(Bird<std::string>::EnableMakeShared);

// CEREAL_REGISTER_POLYMORPHIC_RELATION宏用于cereal在不清楚继承链路时指明继承链路
// 如果子类中有使用cereal::base_class对父类进行正反序列化，那么cereal便清楚继承链路
// 但若没有使用到cereal::base_class，就需要使用CEREAL_REGISTER_POLYMORPHIC_RELATION宏指明
// 在EnableMakeShared类中虽然使用了cereal::base_class，但这仅指明了EnableMakeShared到Bird类的继承
// 而在Bird类中并没有使用cereal::base_class来指明Bird类到IFly类的继承
// 所以这里还是需要指明Bird类到IFly类的继承关系
CEREAL_REGISTER_POLYMORPHIC_RELATION(IFly, Bird<uint32_t>);
CEREAL_REGISTER_POLYMORPHIC_RELATION(IFly, Bird<std::string>);
// 实际上将上述两条语句改为指明IFly与EnableMakeShared类之间的关系也是可以的
//CEREAL_REGISTER_POLYMORPHIC_RELATION(IFly, Bird<uint32_t>::EnableMakeShared);
//CEREAL_REGISTER_POLYMORPHIC_RELATION(IFly, Bird<std::string>::EnableMakeShared);

int main()
{
    {
        auto v = make_unique<vector<shared_ptr<IFly>>>();
        v->push_back(make_shared<Duck>(1));
        v->push_back(Bird<uint32_t>::create(2, 10000));
        v->push_back(Bird<std::string>::create(3, "string data"));
        v->push_back(make_shared<BlackDuck>(4));
        v->push_back(make_shared<BlackDuck>(5));
       
        for (auto &itr : *v) { itr->fly(); }

        // 这里生成二进制数据
        std::ofstream os("out.cereal", std::ios::binary);
        cereal::BinaryOutputArchive archive(os);
        archive(v);
    }
    printf("================================\n");
    {
        auto v = make_unique<vector<shared_ptr<IFly>>>();
        
        // 对刚刚序列化生成的out.cereal文件进行反序列化
        std::ifstream os("out.cereal", std::ios::binary);
        cereal::BinaryInputArchive archive(os);
        archive(v);

        for (auto &itr : *v) { itr->fly(); }
    }

    getchar();
    return 0;
}
```

上面这个程序比较复杂，父类是`IFly`，其子类有`Duck`和`Bird`，`Duck`还有一个`BlackDuck`的子类，而`Bird`类是个模板类，且其又有一个`EnableMakeShared`的内部类。

在cereal文档的多态一节，主要讲述了两个宏，分别是`CEREAL_REGISTER_TYPE`和`CEREAL_REGISTER_POLYMORPHIC_RELATION`。`CEREAL_REGISTER_TYPE`宏用来注册实现了接口的子类。而`CEREAL_REGISTER_POLYMORPHIC_RELATION`宏则用来在cereal不清楚继承链路时指明继承的关系，具体的使用场景结合下面的代码说明细说。

在代码中，`Duck`类继承了`IFly`接口，而`BlackDuck`类又继承了`Duck`类，这两个类都是`IFly`接口的实现，为了让cereal在正反序列化`IFly`接口时可以找到实际的实现，需要使用`CEREAL_REGISTER_TYPE`宏来注册这两个类，表明这两个类是某个接口的实现。如果未注册，比如未注册`Duck`类，那么cereal在正反序列化`IFly`接口（指向的是`Duck`实例）时，无法从接口的实现列表中找到`IFly`接口的`Duck`实现，从而无法正反序列化，导致报错。

在`Duck`类中进行正反序列化时使用了`cereal::base_class<IFly>`方法来对`IFly`进行正反序列化，通过这个方法使得cereal清楚了`Duck`类继承自`IFly`类。而在`BlackDuck`类的正反序列化函数中，也使用了`cereal::base_class<Duck>`方法对`Duck`类进行正反序列化，`cereal`通过该方法知道了`BlackDuck`类继承自`Duck`类。总的来说，cereal通过`cereal::base_class`方法清楚了`IFly`、`Duck`、`BlackDuck`之间的继承关系。上面提到的`CEREAL_REGISTER_POLYMORPHIC_RELATION`宏是用来让cereal明确类之间的继承关系的，但由于类之间使用了`cereal::base_class`方法，这已经让cereal明确了这3者间的继承关系，因此也就不需要用该宏再来指明了。

**总结一下，`CEREAL_REGISTER_TYPE`宏用来说明某个类是某个接口的可能实现，而`CEREAL_REGISTER_POLYMORPHIC_RELATION`宏则用来说明某个类到底是哪个接口的实现。**


下面接着说，在代码中，`Bird`类也继承了`IFly`类，需要注意`Bird`类的构造函数是私有的，其提供了一个静态的`create`方法用于创建该类的实例指针。由于`Bird`类的构造函数是私有的，因此`make_shared`方法也无法构造该类，为了能够使用`make_shared`方法构造`Bird`实例，这里又在`Bird`类中实现了一个`EnableMakeShared`类，该类继承自`Bird`类，仅有一个构造初始化`Bird`类，没有其他多余的方法（不算正反序列化函数）和成员变量，由于`EnableMakeShared`类的构造是公有的，因此就可以使用`make_shared`方法来创建该类的实例指针并强转成Bird类指针返回。这算是一个使用`make_shared`方法创建私有构造类实例的一个方法，但这里的实现实际不太完美。

因为`EnableMakeShared`类是公有的，实际上该类应该是`create`方法的内部类，这样可以避免该类被外部访问，但若无法被外部访问，也就无法进行序列化了，所以这里无奈将其改成了公有的。关于make_shared如何构造私有构造方法的类对象的方法，可以参见文章 [make_shared调用私有构造函数的解决方法](https://bewaremypower.github.io/2019/04/14/make-shared%E8%B0%83%E7%94%A8%E7%A7%81%E6%9C%89%E6%9E%84%E9%80%A0%E5%87%BD%E6%95%B0%E7%9A%84%E8%A7%A3%E5%86%B3%E6%96%B9%E6%B3%95/)。

由于使用`Bird`类的静态`create`方法创建的实际上是`EnableMakeShared`类实例，因此在下面使用`CEREAL_REGISTER_TYPE`宏注册时，注册的也应当是`EnableMakeShared`类，其实之所以在代码例子中引入了`EnableMakeShared`类是因为自己在序列化别的库代码时遇到了这种情况，当时还不明白`EnableMakeShared`类出现的缘由，因此一直注册的是`Bird`类，导致运行一直crash。

在使用`CEREAL_REGISTER_TYPE`宏注册时需要注意Bird类是一个模板类，对于需要使用的任何模板参数都需要一一注册，由于代码中使用了`uint32_t`和`std::string`这两个模板参数，因此也需要分别注册这两个模板参数对应`Bird`的`EnableMakeShared`类。

在`EnableMakeShared`类中，使用了`cereal::base_class<Bird<T>>`方法来指明其继承自`Bird`类，但在`Bird`类中却没有使用`cereal::base_class`方法来指明其继承自`IFly`，因此cereal其实不清楚`IFly`与`Bird`之间的关系。

```bash
// cereal只清楚Bird与EnableMakeShared之间的关系，但不清楚IFly与Bird之间的关系
IFly  -->  Bird  -->  EnableMakeShared
       x          √
```

所以需要使用`CEREAL_REGISTER_POLYMORPHIC_RELATION(IFly, Bird<uint32_t>)`宏来指定`Bird`与`IFly`之间的关系。在指定时同样注意`Bird`是模板类，需要对使用到的不同模板参数分别进行指定。在代码中的注释中也写明了，其实指定`IFly`与`EnableMakeShared`的继承关系也是可以的。在指定后，代码执行便可以正常执行了（可以尝试将`CEREAL_REGISTER_POLYMORPHIC_RELATION`宏删掉后再执行看下结果）。

## 写在最后

整篇文章阐述了cereal的基本用法以及在没有默认构造函数、继承以及多态情况下的使用方法，这实际上是自己在使用cereal过程中遇到的一些问题的总结，并没有非常全面的阐述cereal的用法，因此若希望了解其他细节，可以去官方文档中查阅。

另自己的C++功底其实很差，在使用cereal之前其实很多东西都不明白（比如智能指针的使用），也是在摸索使用cereal过程中恶补了下现代C++的一些知识，因此在这篇总结中也难免会有一些疏漏，若有问题，欢迎指出😄。

## 参考链接

下面是一些参考链接，其中3、4项是两篇介绍C++正反序列化实现的文章。

1. [cereal官方文档](http://uscilab.github.io/cereal/index.html)
2. [make_shared调用私有构造函数的解决方法](https://bewaremypower.github.io/2019/04/14/make-shared%E8%B0%83%E7%94%A8%E7%A7%81%E6%9C%89%E6%9E%84%E9%80%A0%E5%87%BD%E6%95%B0%E7%9A%84%E8%A7%A3%E5%86%B3%E6%96%B9%E6%B3%95/)
2. [Serialization implementation in C++](https://www.codeproject.com/Tips/495191/Serialization-implementation-in-Cplusplus)
3. [ESS: Extremely Simple Serialization for C++](https://www.codeproject.com/Articles/35715/ESS-Extremely-Simple-Serialization-for-C)