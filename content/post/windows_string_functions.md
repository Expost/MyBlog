---
title: "Windows常用字符串函数使用总结"
date: 2019-07-10 16:42:40
categories: [Windows]
---

# 常用字符串函数类型

常用的字符串函数如下：

1.	追加到字符串到另一个字符串类函数。
2.	获取字符串的长度类函数。
3.	字符串拷贝类函数。
4.	格式化字符串类函数。

接下来对这些字符串类函数一一进行说明。

## 追加字符串类函数

追加字符串类的函数有：

1.	strcat（wcscat）
2.	strcat_s(wcscat_s)
3.	strncat(wcsncat)
4.	strncat_s(wcsncat_s)

### 1.strcat(wcscat)函数

函数原型为：
```C++
char *strcat(  
   char *strDestination,  
   const char *strSource   
);  
wchar_t *wcscat(  
    wchar_t *strDestination,  
    const wchar_t *strSource   
);  
```
**参数**

- strDestination：目标字符串指针
- strSource：源字符串指针

**返回值**

函数将返回目标字符串strDestination指针。

**注意**

该函数由于不会检查目标字符串缓冲区是否有足够的空间，因此该函数有缓冲区溢出的风险。

### 2.strcat_s(wcscat_s)函数

该函数是strcat(wcscat)函数的安全版本，函数原型为：
```C++
errno_t strcat_s(  
   char *strDestination,  
   size_t numberOfElements,  
   const char *strSource   
);  
errno_t wcscat_s(  
   wchar_t *strDestination,  
   size_t numberOfElements,  
   const wchar_t *strSource   
);  
```
**参数**

- strDestination：目标字符串指针
- numberOfElements：目标字符串缓冲区可容纳字符的个数。
- strSource：源字符串指针

**返回值**

如果成功，则为0，否则为错误码。

**注意**

第二个参数numberOfElements为目标缓冲区的总大小，而非目标缓冲区的剩余大小。

```C++
char buf[16];  
strcpy_s(buf, 16, "Start");  
strcat_s(buf, 16, " End");               // Correct  
strcat_s(buf, 16 – strlen(buf), " End"); // Incorrect  
```
当出现以下情况时，将会调用 invalid_parameter_handler 函数：

1.	strDestination是NULL指针；
2.	strDestination不是以’\0’结束符结尾的；
3.	strSource是NULL指针；
4.	目标字符串缓冲区太小。

### 3. strncat(wcsncat)函数

函数原型为：
```C++
char *strncat(  
   char *strDest,  
   const char *strSource,  
   size_t count);  
     
wchar_t *wcsncat(  
   wchar_t *strDest,  
   const wchar_t *strSource,  
   size_t count);
```
**参数**

- strDest：目标字符串指针。
- strSource：源字符串指针。
- count：要追加字符串的最大数量。

**返回值**

函数将返回目标字符串的指针。
​	
**注意**

该函数中的count值用来限制要追加字符串的长度，如果count值小于等于strSource字符串的值，那么将只追加count数量的字符，同时会在count数量字符后添加’\0’结束符；如果count大于strSource字符串的长度，则函数检测到strSource字符串的’\0’结束符时会自动停止追加。

该函数同样不会检测目标字符串缓冲区是否有足够的空间，因此该函数同样有缓冲区溢出的风险。

### 4. strncat_s(wcsncat_s)函数

该函数是strncat函数的安全版本，函数原型为：
```C++
errno_t strncat_s(  
   char *strDest,  
   size_t numberOfElements,  
   const char *strSource,  
   size_t count  
);  
errno_t wcsncat_s(  
   wchar_t *strDest,  
   size_t numberOfElements,  
   const wchar_t *strSource,  
   size_t count   
);  
```
**参数**

- strDest：目标字符串指针
- numberOfElements：目标缓冲区的可容纳字符的总个数
- strSource：源字符串的指针。
- count：要追加的字符数或 _TRUNCATE 宏。

**返回值**

如果成功则返回0，否则返回错误码。

**注意**

如果目标缓冲区在可以保留最终的’\0’结束符的情况下还有足够的空间追加count数量的字符，那么该函数将正常执行，否则将会调用invalid_parameter_handler函数。

如果希望尽可能多的在目标字符串尾部追加字符串，那么将count值赋值为_TRUNCATE宏即可。

如果strDestination或strSource是NULL指针，或者numberOfElements是0，则会调用 invalid_parameter_handler 函数。

在下例中：
```C++
char dst[5];
strncpy_s(dst, _countof(dst), "12", 2);
strncat_s(dst, _countof(dst), "34567", 3);
```
dst的长度为5，首先追加2个字符，当再次准备追加3个字符时，由于dst中无法保留最终的’\0’结束符，因此会调用invalid_parameter_handler函数。

## 获取字符串的长度类函数

获取字符串长度的函数有：

1.	strlen(wcslen)函数
2.	strnlen(wcsnlen)函数
3.	strnlen_s(wcsnlen_s)函数

### 1.	strlen(wcslen)函数
函数原型为：
```C++
size_t strlen(  
   const char *str  
);  
size_t wcslen(  
   const wchar_t *str   
);  
```
**参数**

- str：字符串指针

**返回值**

返回str字符串中的字符个数，结尾的’\0’不包含在内。

**注意**

wcslen函数的返回值是按照宽字符结果计算的，因此其行为与strlen行为相同。

strlen函数根据’\0’结束符判断字符串的长度，因此该函数有发生缓冲区溢出的可能。

### 2.	strnlen(wcsnlen)函数

函数原型为：
```C++
size_t strnlen(  
   const char *str,  
   size_t numberOfElements   
);  
size_t wcsnlen(  
   const wchar_t *str,  
   size_t numberOfElements  
);  
```
**参数**

- str：字符串指针
- numberOfElements：字符串缓冲区可容纳字符的个数。

**返回值**

返回str字符串中的字符个数，结尾的’\0’结束符不包含在内。若str字符串的长度超过numberOfElements参数的大小，则最终的结果返回numberOfElements。

**注意**

strnlen函数并非strlen的替代函数，而是用来计算不可信环境下的数据长度，如网络数据包等。在其他环境下使用strlen即可。

### 3. strnlen_s(wcsnlen_s)函数

函数原型为：
```C++
size_t strnlen_s(  
   const char *str,  
   size_t numberOfElements   
);  
size_t wcsnlen_s(  
   const wchar_t *str,  
   size_t numberOfElements  
);  
```
**参数**

- str：字符串指针
- numberOfElements：字符串缓冲区的大小

**返回值**

返回str字符串中的字符个数，结尾的’\0’结束符不包含在内。若str字符串的长度超过numberOfElements参数的大小，则最终的结果返回numberOfElements。

**注意**

该函数与strnlen函数的唯一的区别在于当str字符串指针为NULL指针时，strnlen函数会崩溃，而strnlen_s函数则会返回0.

## 三、字符串拷贝类函数

1.	strcpy(wcscpy)
2.	strcpy_s(wcscpy_s)
3.	strncpy(wcsncpy)
4.	strncpy_s(wcsnpcy_s)

### 1.	strcpy(wcscpy)函数

函数原型为：
```C++
char *strcpy(  
   char *strDestination,  
   const char *strSource   
);  
wchar_t *wcscpy(  
   wchar_t *strDestination,  
   const wchar_t *strSource   
);  
```
**参数**

- strDestination： 目标字符串指针
- strSource：源字符串指针

**返回值**

返回目标字符串指针。

**注意**

由于strcpy函数不会在复制strSource前检查strDestination中的空间是否足够，所以可能会有缓冲区溢出的风险，可以使用strcpy_s(wcscpy_s)函数代替。

### 2. strcpy_s(wcscpy_s)函数

函数原型为：
```C++
errno_t strcpy_s(  
   char *strDestination,  
   size_t numberOfElements,  
   const char *strSource   
);  
errno_t wcscpy_s(  
   wchar_t *strDestination,  
   size_t numberOfElements,  
   const wchar_t *strSource   
);  
```
**参数**

- strDestination：目标字符串指针
- numberOfElements：目标字符串缓冲区容纳字符的个数。
- strSource：源字符串指针

**返回值**

成功返回0，否则返回错误码。

**注意**

strcpy_s函数将strSource地址中的内容（包括结尾的’\0’结束符）复制到strDestination中。目标字符串必须足够大以保存源字符串及其结束符。

如果strDesnation或strSource是NULL指针，或目标字符串缓冲区太小，则会调用invalid_parameter_handler函数。

### 3.strncpy(wcsncpy)函数

函数原型为：
```C++
char *strncpy(  
   char *strDest,  
   const char *strSource,  
   size_t count   
);  
wchar_t *wcsncpy(  
   wchar_t *strDest,  
   const wchar_t *strSource,  
   size_t count   
);  
```
**参数**

- strDest：目标字符串指针
- strSource：源字符串指针
- count：要复制的字符数

**返回值**

返回目标字符串指针。

**注意**

strncpy函数将count数量的strSource字符复制到strDest中并返回strDest。

如果count小于或等于strSource的长度，则不会自动向复制的字符串后追加’\0’结束符。如果count大于strSource的长度，则将在目标字符串后一直添加’\0’结束符至count长度处。

strncpy将不检查strDest中的空间是否足够，因此使用该函数会有缓冲区溢出的风险。

### 4.strncpy_s(wcsncpy_s)函数

函数原型为：
```C++
errno_t strncpy_s(  
   char *strDest,  
   size_t numberOfElements,  
   const char *strSource,  
   size_t count  
);  
errno_t wcsncpy_s(  
   wchar_t *strDest,  
   size_t numberOfElements,  
   const wchar_t *strSource,  
   size_t count   
);  
```
**参数**

- strDest：目标字符串指针
- numberOfElements：目标字符串缓冲区可容纳的字符个数
- strSource：源字符串指针
- count：要复制的字符数或 _TRUNCATE 宏

**返回值**

如果成功，则返回0；如果发生截断则为 STRUNCATE；否则返回错误码。

**注意**

如果strDest或strSource是NULL，或者numberOfElements是0，那么将会调用invalid_parameter_handler函数。	

如果目标字符串缓冲区在保留最终的’\0’结束符的情况下还有足够的空间存储strSource中的字符串，那么将strSource中的字符串拷贝到strDest中，否则将会调用invalid_parameter_handler函数。

如果count是 _TRUNCATE， 那么将strSource中尽可能多的字符拷贝到strDest中并在最后追加’\0’结束符。

示例：
```C++
char dst[5];
strncpy_s(dst, 5, "a long string", 5);
```
目标字符串缓冲区的大小为5，要拷贝字符的个数也为5，那么目标缓冲区最后将不足以追加最后的’\0’结束符，因此最终将会调用invalid_parameter_handler函数。

如果希望截断，则可以按如下方式调用：
```C++
char dst[5];
strncpy_s(dst, 5, "a long string", _TRUNCATE);
strncpy_s(dst, 5, "a long string", 4);
```

## 四、格式化字符串类函数

格式化字符串类函数有：

1.	sprintf(swprintf)
2.	sprintf_s(swprintf_s)
3.	snprintf、_snprintf(_snwprintf)
4.	_snprintf_s(_snwprintf_s)

### 1.sprint(swprintf)函数
函数原型为：
```C++
int sprintf(  
   char *buffer,  
   const char *format [,  
   argument] ...   
);  
int swprintf(  
   wchar_t *buffer,  
   size_t count,  
   const wchar_t *format [,  
   argument]...  
);  
```
**参数**

- buffer：要输出的字符串缓冲区
- count（swprintf函数）：buffre缓冲区可以存储的最大字符串数量。
- format：格式化字符串的控制字符。
- argument：可选参数

**返回值**

返回写入字符的个数（不包括最后的’\0’结束符），如果发生错误，则返回-1。

**注意**

如果buffer 或 format 参数为NULL，将会调用invalid_parameter_handler函数。

由于sprintf无法限制写入的字符数，因此有缓冲区溢出的风险。

swprintf函数是符合ISO C标准的，其需要第二个size_t类型的参数count。

### 2.sprint_s(swprintf_s)函数

函数原型为：
```C++
int sprintf_s(  
   char *buffer,  
   size_t sizeOfBuffer,  
   const char *format,  
   ...   
);  
int swprintf_s(  
   wchar_t *buffer,  
   size_t sizeOfBuffer,  
   const wchar_t *format,  
   ...  
);  
```

**参数**

- buffer：要输出的字符串缓冲区
- sizeOfBuffer：buffer缓冲区中可存储的最大字符数
- format：格式化字符串的控制字符
- …：可选参数

**返回值**

成功则返回写入的字符数，否则返回错误码。

**注意**

sprintf与sprintf_s函数的主要差异在于sprintf_s函数会检查格式字符串中的无效字符，而sprintf函数只检查buffer和format字符串缓冲区是否为NULL。如果有任何错误则会调用invalid_parameter_handler函数。

sprintf与sprintf_s函数的另一个区别是sprintf_s函数要求指定写入缓冲区的大小，如果缓冲区太小而无法打印全部字符串，则会调用invalid_parameter_handler函数。

相较snprintf函数，sprint_s函数确保缓冲区将会以’\0’结束符结束（除非缓冲区长度为0）。

### 3.snprintf、_snprintf(_snwprintf)函数

函数原型为：
```C++
int snprintf(  
   char *buffer,  
   size_t count,  
   const char *format [,  
   argument] ...   
);  
int _snprintf(
   char *buffer,
   size_t count,
   const char *format [,
   argument] ... 
);
int _snwprintf(
   wchar_t *buffer,
   size_t count,
   const wchar_t *format [,
   argument] ... 
);
```

**参数**

- buffer：要输出的字符串缓冲区
- count：缓冲区可最多存储的字符个数。
- format：格式化字符串的控制字符。
- …：可选参数。

**返回值**

在_snprintf（_snwprintf）函数中，假设字符串长度为len（不包括’\0’结束符），那么：
- 当 len < count时， 所有的数据可以写入到缓冲区中，那么返回值为 len
- 当 len = count时， 字符数据可以写入到缓冲区中，但不会添加’\0’结束符，返回值为len.
- 当 len > count时，count数量的字符将被写入缓冲区，且不会添加’\0’结束符，一个负数将被返回。
	

在snprintf函数中，假设字符串的长度为len，那么：
- 当 len < count时，所有的数据可以写入到缓冲区中，并返回len
- 当 len >= count时，snprintf函数将在buffer[count-1]处添加’\0’结束符截断字符串，并返回len。

如果buffer为NULL指针，并且count为0，那么将返回len；如果buffer为NULL指针，并且count不为0，那么将调用invalid_parameter_handler函数。

**注意**

在vs2015之前的文档中没有发现snprintf函数，只有_snprintf函数。在vs2015中的snprintf中，其行为与_snprintf函数不一致，snprintf函数是符合C99标准的。

### 4. _snprintf_s(_snwprintf_s)函数

函数原型为：
```C++
int _snprintf_s(  
   char *buffer,  
   size_t sizeOfBuffer,  
   size_t count,  
   const char *format [,  
   argument] ...   
);  
int _snwprintf_s(  
   wchar_t *buffer,  
   size_t sizeOfBuffer,  
   size_t count,  
   const wchar_t *format [,  
   argument] ...   
);  
```
**参数**

- buffer：要输出字符串的缓冲区
- sizeOfBuffer：buffer缓冲区存储字符的最大个数
- count：写入到缓冲区的字符个数或 _TRUNCATE
- format：格式化字符串的控制字符
- …：可选参数

**返回值**

成功则返回写入buffer的字符个数（不包括’\0’结束符）。

**注意**

如果buffer或是format是NULL指针，或者count小于等于0，那么将会调用invalid_parameter_handler函数。

如果要写入的字符数超过sizeOfBuffer，则会调用invalid_parameter_handler函数。

如果count是 _TRUNCATE，那么_snprintf_s函数将会在保留最后的’\0’结束符的情况下尽可能多在buffer缓冲区中写入字符。如果缓冲区的长度足够整个字符串的写入那么就返回写入字符串的长度，否则截断字符串并返回-1。
​	
示例：
```C++
char *dst = new char[10];
int k = _snprintf_s(dst, 10, 10, "1234567890");
```

上述用法错误，由于sizeOfBuffer与count均为10，因此_snprintf_s函数认为buffer缓冲区中将没有足够的空间追加’\0’结束符，因此会调用invalid_parameter_handler。

```C++
char *dst = new char[10];
int k = _snprintf_s(dst, 10, 20, "12345678901234567890");
```

上述用法错误，由于要写入的字符数超过sizeOfBuffer，因此会调用invalid_parameter_handler。

# 附录

## invalid_parameter_handler说明

大多数安全系数高的CRT函数会校验他们的参数，包括检查空指针，整数是否是有效的范围或枚举值是否有效等。如果发现参数无效则会调用invalid_parameter_handler函数。

当发现无效参数时，C运行时会调用当前的invalid_parameter_handler函数，默认的invalid_parameter_handler函数会调用Watson发送失败报告，导致应用程序崩溃并询问用户他们是否要进行分析。在调试模式下还会导致不合格的断言。

为了改变默认invalid_parameter_handler函数的行为，可以通过函数\_set_invalid_parameter_handler、_set_thread_local_invalid_parameter_handler设置自己的无效处理程序。

