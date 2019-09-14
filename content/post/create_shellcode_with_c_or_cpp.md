---
title: 使用c/c++编写shellcode
date: 2016-04-15 21:50:35
categories: [C++]
---


之前看了一个后门的源代码，其中的一个功能很有意思，是从远程获取一段shellcode，然后分配内存执行之。这样的话，在本地是不会留下来任何痕迹的，具有很好的免杀效果。在这种情况下，因为对shellcode的长度没有任何要求，那么每个功能都要使用汇编来写shellcode的话就会很麻烦。使用c语言等高级语言来写shellcode的话就会好很多。

参考了网上的一些教程，学习了使用c/c++编写shellcode的方法，在此总结。参考文章如下：

[http://blog.sina.com.cn/s/blog_7d5a09f90102w7do.html](http://blog.sina.com.cn/s/blog_7d5a09f90102w7do.html)

[http://blog.idf.cn/2013/12/writing-shellcode-with-a-c-compiler/](http://blog.idf.cn/2013/12/writing-shellcode-with-a-c-compiler/)

第一篇文章非常系统的讲述了编写shellcode需要注意的各个要点，同时没有使用c改用c++实现，通过c++的继承，将常用的API函数地址在父类当中初始化好，当编写shellcode的时候通过继承父类，便可以很方便的使用那些API函数，这将大大简化编写shellcode的麻烦程度，除此之外，还有c++的其他高级特性，比如使用虚函数指针之类的，似乎有将shellcode编写工程化的感觉。因为使用了C++，所以导出shellcode的话略麻烦，几乎将整个代码段都导出出来了，因此最终的shellcode会特别长，不过幸好对shellcode长度没有什么要求。

第二篇文章则主要是使用c语言编写，整个过程看起来就比第一篇文章看起来简单明了。其中获取dll地址以及从dll中获取函数地址的方法要比第一篇文章更为清晰，其实两篇文章的这个部分实质上都是差不多的，一个是真的根据函数名进行比对，另一个是根据函数名的hash值进行比对，一个是使用c语言编写，一个是使用汇编编写的。整体来说，我更倾向于第二篇文章介绍的方法。第二篇文章获取shelllcode的方法也比第一篇文章介绍的要清晰。不过由于第一篇文章使用的基于类继承的方法写shellcode，因此代码结构就比第二篇文章介绍的要复杂，所以第一篇文章采用将整个代码段拷出来执行的方法也就属无奈之举了。

言归正传。下面是一个普通的正常程序的代码，编译环境为win10，vs2015 community，debug版本。

```C++
#include <stdio.h>
#include <Windows.h>
#pragma warning(disable:4996)
int iGlobalTime = 100;

typedef void(*ptrFunc)(const int time);


void OurSleep(const int time) {
    static int iSleepTime = time;
    Sleep(iSleepTime);
}

void ShowInfo(const char *ptrString){
    char ptrTmpString[100] = { 0 };

    strcpy(ptrTmpString, ptrString);

    printf("%s\n", ptrTmpString);
}

int main() {
    ptrFunc p = OurSleep;
    char *ptrString = "This is for test";

    ShowInfo(ptrString);
    p(iGlobalTime);
    
    return 0;
}
```

上面这个程序用到了全局变量，静态变量，局部变量，常量字符串，函数指针，自定义函数调用，系统API调用,C库函数调用。

看一下上面程序使用各个部分的反汇编代码（因为是多次运行程序又开启的随机地址，所以地址显示的会不相同）：

全局变量：
```
p(iGlobalTime);
012B3828 8B F4                mov         esi,esp  
012B382A A1 00 A0 2B 01       mov         eax,dword ptr ds:[012BA000h]  ;地址为绝对地址
012B382F 50                   push        eax  
012B3830 FF 55 F8             call        dword ptr [ebp-8]  
```

静态变量：
```
Sleep(iSleepTime);
00DB17D7 A1 48 A1 DB 00       mov         eax,dword ptr ds:[00DBA148h]  ;地址为绝对地址
00DB17DC 50                   push        eax  
00DB17DD FF 15 00 B0 DB 00    call        dword ptr ds:[00DBB000h]  ;地址为绝对地址
```
上面这个也反映出调用系统API Sleep 函数时，地址也为绝对地址。

局部变量：
```
strcpy(ptrTmpString, ptrString);
00074BDC 8B 45 08             mov         eax,dword ptr [ebp+8]  ;[ebp + 8]里为参数ptrString的地址
00074BDF 50                   push        eax  
00074BE0 8D 4D 94             lea         ecx,[ebp-6Ch]  ;将地址 ebp - 6ch 放到ecx中，此为ptrTmpString的地址，此地址为相对地址
00074BE3 51                   push        ecx  
00074BE4 E8 F0 C7 FF FF       call        000713D9   ;strcpy函数的地址为相对地址，相对地址为：ffffc7f0
```
上面也反映出调用c库函数时，使用的地址为相对地址。

常量字符串：
```
char *ptrString = "This is for test";
0031116D C7 45 FC AC 21 31 00 mov         dword ptr [ebp-4],3121ACh  ;此处地址为绝对地址
```

函数指针：
```
ptrFunc p = OurSleep;
00311166 C7 45 F8 80 10 31 00 mov         dword ptr [ebp-8],311080h  ;此时函数指针保存的值也为绝对地址
p(iGlobalTime);
00311180 8B 0D 28 30 31 00    mov         ecx,dword ptr ds:[00313028h]  
00311186 51                   push        ecx  
00311187 FF 55 F8             call        dword ptr [ebp-8] ;此时call的是绝对地址
```

自定义函数调用：
```
ShowInfo(ptrString);
00311174 8B 45 FC             mov         eax,dword ptr [ebp-4]  
00311177 50                   push        eax  
00311178 E8 63 FF FF FF       call        003110E0  ;此时地址为相对地址
0031117D 83 C4 04             add         esp,4  
```

综上，

使用绝对地址的有：

- 全局变量
- 静态变量
- 常量字符串
- 函数指针
- 系统API调用

使用相对地址的有：

- 局部变量
- 自定义函数调用
- c库函数调用

因为shellcode代码的特性就是地址无关性，也即运行不需进行重定位，所以那些使用绝对地址的东西是不应该使用的。对于全局变量，可以采用局部变量代替，静态变量暂时无法替代，常量字符串可以使用局部字符串数组代替，函数指针避免使用，系统API虽说是使用的绝对地址，但是这个地址可以通过加载dll，获取dll的导出表地址从而获得，因此实际上也是可以使用的，因此保存有系统API地址的函数指针也是可以使用的。

对于相对地址的东西，按道理来说是都可以使用的，但是实际上c库函数也是不能使用的，原因是我们无法保证c库函数内部使用了全局变量或是静态变量以及字符串等内容，因此，c运行时库实际上也是应该避免使用的，除非我们自己实现一个c库，链接的时候链接进去。

另外，这里要说明一点，关于自定义函数使用相对地址进行调用，在debug版本当中，因为编译器开启了增量链接，所以在调用自定义函数的时候，会先跳到一个地址，然后再在这个地址的地方跳到函数体的地方，在实际使用c编写shelllcode的时候，使用release版本，这个时候，在call的时候是直接根据相对地址跳到函数体那里。

综上，我们可以使用的有：系统API调用，局部变量，自定义函数，保存有系统API地址的函数指针。

接下来要解决的问题是，如果调用系统API。

在windows操作系统当中，PEB结构当中保存了当前进程加载的dll的信息。关于PEB结构可以参考下面这两篇文章：

[PEB结构----枚举用户模块列表](http://bbs.pediy.com/showthread.php?t=52398)
[通过PEB结构遍历进程模块](http://www.cnblogs.com/wolf89/archive/2012/12/15/2819858.html)

尤其是第二篇文章的图非常好，引用如下：
![](http://pic002.cnblogs.com/2012/478266/2012121522041290.jpg)

下面这段代码的功能是遍历当前进程加载的DLL信息：

```C++
#include <Windows.h>
#include <stdio.h>
#include <winternl.h>


void iteratorDll() {
    PPEB peb;
    _asm {
        mov eax,fs:[0x30]
        mov peb,eax
    }
    LDR_DATA_TABLE_ENTRY *module_ptr, *first_mod;
    module_ptr = (PLDR_DATA_TABLE_ENTRY)peb->Ldr->InMemoryOrderModuleList.Flink;
    first_mod = module_ptr;
    
    do {
        //注意dll的名字是按照宽字符存储的
        wprintf(L"%s\t\t%x\t\t%x\t\t%x\n", module_ptr->FullDllName.Buffer, module_ptr->DllBase,module_ptr->Reserved2[0], LoadLibrary(module_ptr->FullDllName.Buffer));
        module_ptr = (PLDR_DATA_TABLE_ENTRY)(*(void**)module_ptr);
    } while (first_mod != module_ptr);
}

int main() {

    iteratorDll();

    return 0;
}
```

代码中获取的那个DllBase值我感到很奇怪，看名字是dll的基址，但是和后面使用LoadLibrary函数获取到的不相同，这就很奇怪。后来用PE工具看了看，那个DllBase的值和SizeOfImage的值是相同的，看了几个dll，都是这样。

获取到dll在内存中的基址后，就可以获取想要调用API的地址了。获取函数的地址的方式很简单，根据dll的导出表可以获得相应API的在dll中的偏移地址，然后再和dll的基址相加，就可以获取到API在整个内存空间中的地址。

下面是相关部分代码：

```C++
#include <Windows.h>
#include <stdio.h>
#include <winternl.h>

void iteratorFuncName(HMODULE hModule) {
    IMAGE_DOS_HEADER *dos_header;
    IMAGE_NT_HEADERS *nt_headers;
    IMAGE_EXPORT_DIRECTORY *export_dir;
    DWORD *names, *funcs;
    WORD *nameords;

    dos_header = (IMAGE_DOS_HEADER*)hModule;
    nt_headers = (IMAGE_NT_HEADERS*)((char*)hModule + dos_header->e_lfanew);
    export_dir = (IMAGE_EXPORT_DIRECTORY*)((char*)hModule + nt_headers->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress);
    names = (DWORD*)((char*)hModule + export_dir->AddressOfNames);
    funcs = (DWORD*)((char*)hModule + export_dir->AddressOfFunctions);
    nameords = (WORD*)((char*)hModule + export_dir->AddressOfNameOrdinals);
    for (int i = 0; i < export_dir->NumberOfNames; i++) {
        char *string = (char*)hModule + names[i];
        DWORD funcrva = funcs[nameords[i]];
        printf("Name:%s\tAddress:%x\tTureAddress:%x\n", string, (char*)hModule + funcrva, GetProcAddress(hModule, string));
    }
}

int main() {
    iteratorFuncName(LoadLibrary(L"kernel32.dll"));
    return 0;
}
```
上述代码用来输出某个dll的所有导出函数，在以kernel32.dll为例当中，会发现第一个和第二个函数的输出地址与使用GetProcAddress函数输出的地址不相同，这是因为，这里的代码没有处理使用中转的函数。如果想要处理那些带中转函数的dll，可以参考这篇文章：[完美实现GetProcAddress](http://bbs.pediy.com/showthread.php?t=121226)。


实际测试当中遇到了一个比较蛋疼的问题，当根据dll名获取dll在内存当中的基址的时候，那个dll名的大小写很重要，在win10中，kernel32.dll在内存中的名字全是大写的KERNEL32.DLL，而user32.dll则是USER32.dll，他们的标准完全不一样，暂不清楚在其他平台，比如win8或是win7下情况如何，为了避免这个问题，因此感觉还是先把loadlibrary和getprocaddress这两个函数给加载下来比较好。

当可以获取到API的时候，接下来就可以进行shellcode的编写了。

这里使用两种方式编写，一种使用c语言，另一种使用C++的类方法方式进行编写。

c语言的例子，环境为win10，vs2015 community,release版本，关闭了安全检查，关闭了优化（实际测试中发现即使打开O1优化也无影响）：

```C++
#include <stdio.h>
#include <Windows.h>
#include <winternl.h>

#pragma warning(disable;4996);
HMODULE __stdcall FindDllAddress(LPCWSTR);
FARPROC __stdcall FindFuncAddress(HMODULE, char*);

void __stdcall shell_code(){
    char szMsgFuncName[] = { 'M','e','s','s','a','g','e','B','o','x','A',0 };
    WCHAR wcsUserDllName[] = { 'U','S','E','R','3','2','.','d','l','l',0 };
    HMODULE h = FindDllAddress(wcsUserDllName);
    typedef int(__stdcall *MSGBOX)(HWND, LPCSTR, LPCSTR, UINT);
    MSGBOX pMsgBox;
    pMsgBox = (MSGBOX)FindFuncAddress(h, szMsgFuncName);
    
    pMsgBox(NULL, szMsgFuncName, szMsgFuncName, 0);
}

bool __stdcall _strcmp(const char *str1, const char *str2) {
    int ret = 0;
    while (!(ret = *(unsigned char *)str1 - *(unsigned char*)str2) && *str2)
        ++str1, ++str2;
    if (ret == 0)
        return true;
    else
        return false;
}

bool __stdcall _wcscmp(const wchar_t *str1, const wchar_t *str2) {
    int ret = 0;
    while (!(ret = *(wchar_t *)str1 - *(wchar_t*)str2) && *str2)
        ++str1, ++str2;
    if (ret == 0)
        return true;
    else
        return false;
}

HMODULE __stdcall FindDllAddress(LPCWSTR strDllName) {
    PPEB peb;
    _asm {
        mov eax, fs:[0x30]
        mov peb, eax
    }
    LDR_DATA_TABLE_ENTRY *module_ptr, *first_mod;
    module_ptr = (PLDR_DATA_TABLE_ENTRY)peb->Ldr->InMemoryOrderModuleList.Flink;
    first_mod = module_ptr;
    do {
        if (_wcscmp(strDllName, module_ptr->FullDllName.Buffer)) {
            return (HMODULE)module_ptr->Reserved2[0];
        }
        module_ptr = (PLDR_DATA_TABLE_ENTRY)(*(void**)module_ptr);
    } while (first_mod != module_ptr);
    return (HMODULE)NULL;
}

FARPROC __stdcall FindFuncAddress(HMODULE module, char *strFuncName){
    IMAGE_DOS_HEADER *dos_header;
    IMAGE_NT_HEADERS *nt_headers;
    IMAGE_EXPORT_DIRECTORY *export_dir;
    DWORD *names, *funcs;
    WORD *nameords;
    
    dos_header = (IMAGE_DOS_HEADER *)module;
    nt_headers = (IMAGE_NT_HEADERS *)((char *)module + dos_header->e_lfanew);
    export_dir = (IMAGE_EXPORT_DIRECTORY *)((char *)module + nt_headers->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress);
    names = (DWORD *)((char *)module + export_dir->AddressOfNames);
    funcs = (DWORD *)((char *)module + export_dir->AddressOfFunctions);
    nameords = (WORD *)((char *)module + export_dir->AddressOfNameOrdinals);

    for (int i = 0; i < export_dir->NumberOfNames; i++){
        char *string = (char *)module + names[i];
        
        if (_strcmp(string,strFuncName)){
            WORD nameord = nameords[i];
            DWORD funcrva = funcs[nameord];
            return (FARPROC)((char *)module + funcrva);
        }
    }

    return NULL;
}
void __declspec(naked) END_SHELLCODE(void) {}

void CreateShellCode(char *szFileName) {
    FILE *output_file = fopen(szFileName, "wb");
    fwrite(shell_code, (int)END_SHELLCODE - (int)shell_code, 1, output_file);
    fclose(output_file);
}

void LoadShellCode(char *szFileName) {
    FILE *file = fopen(szFileName, "rb");
    fseek(file, 0, 2);
    ULONG uFileLen = ftell(file);
    fseek(file, 0, 0);
    PVOID pExecMemory = VirtualAlloc(NULL, uFileLen, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    fread(pExecMemory, uFileLen, 1, file);
    fclose(file);

    _asm call pExecMemory;

    VirtualFree(pExecMemory, 0, MEM_RELEASE);
}

int main(int argc, char *argv[]){
    char *strShellCodeName = "shellcode.bin";
    CreateShellCode(strShellCodeName);
    LoadShellCode(strShellCodeName);
    return 0;
}
```
上述程序承担了生成器和加载器的职责，运行之后，会先生成相应的shellcode，然后再加载运行。生成的shellcode的大小为672字节。

使用上述方法编写shellcode扩展性不太好，因此借鉴最开始的第一篇文章，采用c++编写shellcode。

c++代码如下，环境为win10，vs2015 community，release版本，关闭了安全检查，关闭了优化（这个开启优化会把显示的字符串优化掉），同时设置入口点为main函数。

ShellCode.h
```C++
#pragma once
#include <Windows.h>

typedef HMODULE(__stdcall *__LoadLibrary)(LPCTSTR);
typedef FARPROC(__stdcall *__GetProcAddress)(HMODULE, LPCSTR);
typedef HANDLE(__stdcall *__GetStdHandle)(DWORD);
typedef BOOL(__stdcall *__WriteFile)(HANDLE, LPCVOID, DWORD, LPDWORD, LPOVERLAPPED);

class ShellCode {
private:
    HMODULE GetDllAddress(LPCWSTR);
    FARPROC GetFuncAddress(HMODULE,LPCSTR);
    bool _strcmp(const char *str1, const char *str2);
    bool _wcscmp(const wchar_t *str1, const wchar_t *str2);
protected:
    __LoadLibrary _LoadLibrary;
    __GetProcAddress _GetProcAddress;
    __WriteFile _WriteFile;
    __GetStdHandle _GetStdHandle;
public:
    ShellCode();
};
```

ShellCode.cpp
```C++
#include "ShellCode.h"
#include <winternl.h>

ShellCode::ShellCode() {
    WCHAR wcsKernelDllName[] = { 'K','E','R','N','E','L','3','2','.','D','L','L',0 };
    char szLoadDllFuncName[] = { 'L','o','a','d','L','i','b','r','a','r','y','W',0 };
    char szGetProcAddressFuncName[] = { 'G','e','t','P','r','o','c','A','d','d','r','e','s','s',0 };
    char szGetStdHandle[] = { 'G','e','t','S','t','d','H','a','n','d','l','e',0 };
    char szGetWriteFile[] = { 'W','r','i','t','e','F','i','l','e',0 };

    HMODULE hKernel = GetDllAddress(wcsKernelDllName);
    _LoadLibrary = (__LoadLibrary)GetFuncAddress(hKernel, szLoadDllFuncName);
    _GetProcAddress = (__GetProcAddress)GetFuncAddress(hKernel, szGetProcAddressFuncName);
    _GetStdHandle = (__GetStdHandle)_GetProcAddress(hKernel, szGetStdHandle);
    _WriteFile = (__WriteFile)_GetProcAddress(hKernel, szGetWriteFile);
}

HMODULE ShellCode::GetDllAddress(LPCWSTR szDllName) {
    PPEB peb;
    _asm {
        mov eax, fs:[0x30]
        mov peb, eax
    }
    LDR_DATA_TABLE_ENTRY *module_ptr, *first_mod;
    module_ptr = (PLDR_DATA_TABLE_ENTRY)peb->Ldr->InMemoryOrderModuleList.Flink;
    first_mod = module_ptr;
    do {
        if (_wcscmp(szDllName, module_ptr->FullDllName.Buffer)) {
            return (HMODULE)module_ptr->Reserved2[0];
        }
        module_ptr = (PLDR_DATA_TABLE_ENTRY)(*(void**)module_ptr);
    } while (first_mod != module_ptr);
    return (HMODULE)NULL;
}

FARPROC ShellCode::GetFuncAddress(HMODULE module,LPCSTR szFuncName) {
    IMAGE_DOS_HEADER *dos_header;
    IMAGE_NT_HEADERS *nt_headers;
    IMAGE_EXPORT_DIRECTORY *export_dir;
    DWORD *names, *funcs;
    WORD *nameords;

    dos_header = (IMAGE_DOS_HEADER *)module;
    nt_headers = (IMAGE_NT_HEADERS *)((char *)module + dos_header->e_lfanew);
    export_dir = (IMAGE_EXPORT_DIRECTORY *)((char *)module + nt_headers->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress);
    names = (DWORD *)((char *)module + export_dir->AddressOfNames);
    funcs = (DWORD *)((char *)module + export_dir->AddressOfFunctions);
    nameords = (WORD *)((char *)module + export_dir->AddressOfNameOrdinals);

    for (int i = 0; i < export_dir->NumberOfNames; i++) {
        char *string = (char *)module + names[i];

        if (_strcmp(string, szFuncName)) {
            WORD nameord = nameords[i];
            DWORD funcrva = funcs[nameord];
            return (FARPROC)((char *)module + funcrva);
        }
    }
    return NULL;
}

bool ShellCode::_strcmp(const char *str1, const char *str2) {
    int ret = 0;
    while (!(ret = *(unsigned char *)str1 - *(unsigned char*)str2) && *str2)
        ++str1, ++str2;
    if (ret == 0)
        return true;
    else
        return false;
}

bool ShellCode::_wcscmp(const wchar_t *str1, const wchar_t *str2) {
    int ret = 0;
    while (!(ret = *(wchar_t *)str1 - *(wchar_t*)str2) && *str2)
        ++str1, ++str2;
    if (ret == 0)
        return true;
    else
        return false;
}
```

MyShellCode.h
```C++
#pragma once
#include "ShellCode.h"

typedef int(__stdcall *__MessageBoxA)(HWND, LPCSTR, LPCSTR, UINT);

class MyShellCode:public ShellCode {

protected:
    __MessageBoxA _MessageBoxA;
public:
    MyShellCode();
    void running();
};
```

MyShellCode.cpp
```C++
#include "MyShellCode.h"

MyShellCode::MyShellCode() {
    char szMessageBoxAFuncName[] = { 'M','e','s','s','a','g','e','B','o','x','A',0 };
    WCHAR szUserDllName[] = { 'u','s','e','r','3','2','.','d','l','l',0 };
    WCHAR wcsKernelDllName[] = { 'K','E','R','N','E','L','3','2','.','D','L','L',0 };
    char szLoadDllFuncName[] = { 'L','o','a','d','L','i','b','r','a','r','y','A',0 };
    HMODULE hUser32 = _LoadLibrary(szUserDllName);
    _MessageBoxA = (__MessageBoxA)_GetProcAddress(hUser32, szMessageBoxAFuncName);
}

void MyShellCode::running() {
    char szTmp[] = { 'T','h','i','s',' ','m','y','s','h','l','l','c','o','d','e','\n',0 };
    HANDLE hStd = _GetStdHandle(-11);
    _WriteFile(hStd, szTmp, 16, 0, 0);
    _MessageBoxA(NULL, szTmp, szTmp, 0);
}
```

MAIN.cpp
```C++
#include "MyShellCode.h"
#include <stdio.h>

int main() {
    MyShellCode m;
    m.running();
    
    return 0;
}
```

因为使用了类，再加上文件结构复杂，因此无法再像使用c编写shellcode那样程序自己将shellcode剪切出来。为此，只能够直接执行此程序，通过另外一个程序根据该程序的PE结构获取程序的代码段的入口点以及代码段的长度（这也是为什么要将程序的入口点设置为main，如果不设置，那么真正的入口点将不是main而是CRTMainstartup），之后根据这个信息将整个代码段给剪切出来，因为整个代码段都是位置无关的代码，因此拷贝出来的代码段是可以当作shellcode执行的。

在该程序中，ShellCode类是基类，里面封装了几个函数，暂时假定为常用的基本函数吧。之后创建MyShellCode类，该类继承自ShellCode类，这样在MyShellCode类中就可以方便的使用ShellCode基类中的函数，如果在MyShellCode类中想要使用其他的函数，自行加载其他函数。这样，开发shellcode就会简便很多。

剪切拷贝代码段的代码如下：

```C
#include <stdio.h>
#include <windows.h>
#include <winnt.h>
#pragma warning(disable:4996)

#define OFFSET_OPTHDR_START 0x3c
IMAGE_NT_HEADERS ntHdrs;

void locateNTHdrStart(FILE * fp){
    int hdrStart;
    fseek(fp, OFFSET_OPTHDR_START, SEEK_SET);
    fread(&hdrStart, sizeof(hdrStart), 1, fp);
    fseek(fp, hdrStart, SEEK_SET);
}

void readHdrs(FILE * fp){
    locateNTHdrStart(fp);
    fread(&ntHdrs, sizeof(ntHdrs), 1, fp);
}

void main(int argC, char ** args){
    if (argC != 2){
        printf("please input like this: xxx filename(to get code)\n");
        return;
    }
    FILE * fp;
    fp = fopen(args[1], "rb");
    if (fp == NULL){
        printf("file does not exits\n");
        return;
    }
    readHdrs(fp);

    int sectionNum = ntHdrs.FileHeader.NumberOfSections;
    IMAGE_SECTION_HEADER codeSectionHdr;
    bool found = false;
    
    for (int i = 0; i < sectionNum; i++) {
        fread(&codeSectionHdr, sizeof(IMAGE_SECTION_HEADER), 1, fp);
        if ((codeSectionHdr.Characteristics & 0x00000020) == 0x00000020){
            found = true;
            break;
        }
    }
    if (!found){
        printf("cannot find code section\n");
        return;
    }
    int codeLen = codeSectionHdr.Misc.VirtualSize;
    char * code = (char *)malloc(codeLen);
    
    fseek(fp, codeSectionHdr.PointerToRawData, SEEK_SET);
    fread(code, codeLen, 1, fp);
    fclose(fp);

    fp = fopen("shellcode.bin", "wb");
    fwrite(code, codeLen, 1, fp);
    fclose(fp);

}
```

输入参数运行之，生成相应的shellcode，在我这里生成的大小为1509字节，已经相当大了。

运行shellcode的代码如下：

```C
#include <stdio.h>
#include <Windows.h>
#pragma warning(disable:4996)

void LoadShellCode(const char *szFileName) {
    FILE *file = fopen(szFileName, "rb");
    fseek(file, 0, 2);
    ULONG uFileLen = ftell(file);
    fseek(file, 0, 0);
    PVOID pExecMemory = VirtualAlloc(NULL, uFileLen, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    fread(pExecMemory, uFileLen, 1, file);
    fclose(file);

    _asm call pExecMemory;

    VirtualFree(pExecMemory, 0, MEM_RELEASE);
}

int main(int argc, char *argv[]) {
    char *strShellCodeName = "shellcode.bin";
    LoadShellCode(strShellCodeName);
    return 0;
}
```


以上便是使用c/c++编写shellcode的过程，说句实话，私以为在漏洞利用当中是绝对不会使用这种高级语言生成的shellcode，若问使用c/c++编写shellcode有什么用，只能看那些特殊应用场景了，比如外网产品出现了问题，那么就可以通过这种方式生成shellcode动态代码下发修复。