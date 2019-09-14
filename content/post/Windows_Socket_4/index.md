---
title: Windows网络编程学习（四）
date: 2015-01-15 16:16:30
categories: [Windows,网络编程]
---

这一篇文章总结下windows网络编程中重叠IO之事件通知模型的学习。

从本质上来说，重叠IO模型才是真正的异步模型，之前的WSA消息和WSA事件模型都不算是真正意义上的异步模型。具体来说在之前的WSA消息和事件模型中，当有消息到来的时候，系统会通知我们调用recv()函数，而recv()函数是阻塞的，还是会等待数据接收完毕后才开始返回。而重叠IO模型则是调用WSARecv()函数，然后立即返回，当数据被拷贝进数据缓冲区的时候，系统才通知我们去处理，这时候我们处理的时候，数据已经在我们的缓冲区了，省去了继续等待数据拷贝进缓冲区的时间。因此才说重叠IO模型才是真正的异步模型。

重叠IO是一种进行IO操作时的一种异步模型，无论是文件IO还是其他的什么都可以使用，这里是使用重叠IO模型进行网络通讯。

重叠IO模型中具体的实现方法有两种，分别是事件通知和完成例程。这次的是事件通知模型。之所以叫事件通知是因为异步还是基于事件的，这点和上一篇的WSA事件模型相类似。

在这种模型中，我们还需要创建WSA事件对象，然后调用WSAWaitForMultipleEvents()函数根据事件的有无信号来判断是否有套接字发生网络事件，但除了判断是否有信号外还需要调用另一函数，即WSAGetOverlappedResult()函数来判断套接字重叠操作的情况，而这需要另外一种新的结构体，WSAOVERLAPPED结构体。该结构体的定义如下：

```C
typedef struct _WSAOVERLAPPED {
    DWORD        Internal;      //该字段由系统使用，我们不用考虑
    DWORD        InternalHigh;  //该字段由系统使用，我们不用考虑
    DWORD        Offset;        //该字段由系统使用，我们不用考虑
    DWORD        OffsetHigh;    //该字段由系统使用，我们不用考虑
    WSAEVENT     hEvent;        //这个是我们使用WSACreateEvent()函数创建的WSA事件对象
} WSAOVERLAPPED, FAR * LPWSAOVERLAPPED;
```
通过上述结构体的最后一个参数，就将我们创建的事件对象和WSAOVERLAPPED结构体给关联了起来。


下面说明一下这种模型需要的一些函数： WSASocket(),WSACreateEvent(),WSAResetEvent(),WSAWaitForMultipleEvents(),WSAGetOverlappedResult()和WSARecv()函数。除了之前介绍过的函数，其他的函数定义如下：

首先是WSASocket()函数，根据函数名就可以看出这个函数是用来创建套接字的。

```C
SOCKET WSASocket (
  int af,                             //address family的缩写
  int type,                           //设置传输类型，tcp是SOCK_STREAM,udp是SOCK_DGRAM
  int protocol,                       //设置传输协议，tcp是IPPRROTO_TCP,udp是IPPROTO_UDP
  LPWSAPROTOCOL_INFO lpProtocolInfo,  //一个指向PROTOCOL_INFO结构的指针，该结构定义所创建套接口的特性，这里设为NULL
  GROUP g,                            //保留给未来使用的套接字组。套接口组的标识符，这里设置为0
  DWORD dwFlags                       //这个参数是套接字的属性设置，如果要使用重叠IO模型的话，这个选项必须设置为 WSA_FLAY_VOERLAPPED
);
```
对比之前的socket函数可知，这个函数比之前的socket函数多了三个参数，而且又最后一个参数最重要。但其实，socket函数创建的套接字的默认属性就是WSA\_FLAY\_VOERLAPPED。

接收消息使用的函数是WSARecv函数，定义如下：

```C
int WSARecv (
  SOCKET s,                                               //要接收消息的套接字
  LPWSABUF lpBuffers,                                     //指向WSABUF结构体数组的指针，用来接收数据
  DWORD dwBufferCount,                                    //lpBuffers数组中成员的数量
  LPDWORD lpNumberOfBytesRecvd,                           //如果接收完成，所接收数据的字节数量
  LPDWORD lpFlags,                                        //标志位
  LPWSAOVERLAPPED lpOverlapped,                           //指向WSAOVERLAPPED结构体的指针
  LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionROUTINE  //完成例程
);
```
关于这个函数需要说明几点。首先是第二个参数中的WSABUF结构体，这个结构体的定义如下：
 
```C
typedef struct __WSABUF {
    u_longlen;     // 缓冲区的长度
    char FAR *buf; // 指向缓冲区的指针
} WSABUF, FAR * LPWSABUF;
```
第二个参数的要求是一个指向WSABUF数组的指针，这也就表示WSARecv()函数允许有多个缓冲区接收数据。

如果lpOverlapped参数和lpCompletionROUTINE参数都被设为NULL，那么套接字就将被作为非重叠套接字使用

如果lpCompletionROUTINE参数被设为NULL，呢么当数据接收完成后，lpOverlapped指针指向的WSAOVERLAPPED结构体中的事件对象就会被设置成有信号状态，从而通知应用程序进行相应的处理。

如果lpCompletionROUTINE参数不是NULL，那么lpOverlapped参数中的事件对象就会被忽略。下一篇会总结重叠IO之完成例程的学习，而重叠IO之完成例程就需要设置WSARecv函数的最后一个参数，而在事件通知中，最后一个参数则设为NULL。

关于该函数的返回值，如果重叠操作立即完成，那么函数会返回0，并且lpNumberOfBytesRecvd参数指向的变量是所接收数据的字节数。如果重叠IO为能够立即完成，那么函数会返回SOCKET_ERROR值，错误代码是WSA\_IO\_PENDING，这种情况下lpNumberOfBytesRecvd指明的变量将不会被改变。

WSAGetOverlappedResult()函数的定义如下：

```C
BOOL WSAGetOverlappedResult (
  SOCKET s,                      //套接字
  LPWSAOVERLAPPED lpOverlapped,  //发起重叠操作WSAOVERLAPPED结构指针
  LPDWORD lpcbTransfer,          //实际发送或是接收的数据的字节数
  BOOL fWait,                    //函数返回的方式。如果为真，那么当重叠操作完成后函数才返回，如果为假，那么当操作仍处于等待执行状态时，函数会返回假，错误代码是WSA_IO_INCOMPLETE
  LPDWORD lpdwFlags              //接收完成的附加标志
);
```

当函数返回为真时，表示重叠操作已经完成，当返回假时，可能的原因可能有：

- 重叠操作还未完成
- 重叠操作完成，但是还存在一些错误
- 由于该函数的一个或多个参数错误，导致不能确定重叠操作完成的状态

整个程序的逻辑是：

1. 创建有WSAOVERLAPPED属性的套接字
2. 定义WSAOVERLAPPED结构
3. 调用WSACreateEvent()函数创建事件对象，并将该事件分配给WSAOVERLAPPED结构的最后一个成员
4. 调用输入或输出函数进行重叠IO
5. 调用WSAWaitForMultipleEvents()函数，等待事件对象变为有信号状态
6. 调用WSAResetEvent()函数重置事件对象
7. 调用WSAGetOverlappedResult()函数，判断重叠操作完成的状态
8. 对数据进行处理


下面是代码，客户端代码同文章一：（win7  VC6.0）

```C
#include <winsock2.h>
#include <stdio.h>
#pragma comment(lib,"ws2_32.lib")

#define MSGSIZE 1024
#define PORT 5000

//定义数据结构
typedef struct{
    WSAOVERLAPPED overlap;
    WSABUF Buffer;
    DWORD NumberOfBytesRecevd;
    DWORD Flags;
}IO_OVERDATA;

int ConnectNum=0;


//创建全局socket，事件以及重叠结构的数组，数组的大小都是MAXIMUM_WAIT_OBJECTS宏确定的，该宏代表的大小是64，这也是限制
SOCKET MySockets[MAXIMUM_WAIT_OBJECTS];
WSAEVENT MyEvents[MAXIMUM_WAIT_OBJECTS];
IO_OVERDATA *MyOverData[MAXIMUM_WAIT_OBJECTS];

//定义线程函数
DWORD WINAPI ServerThread(LPVOID lpParam);

//定义清理函数
void Cleanup(int);

int main(){

    //初始化套接字及定义变量
    WSADATA wsaData;
    SOCKET sListen,sClient;
    SOCKADDR_IN localaddr={0},clientaddr={0};
    WSAStartup(MAKEWORD(2,2),&wsaData);

    //创建监听套接字
    sListen=socket(AF_INET,SOCK_STREAM,0);   //socket创建的套接字默认就有WSAOVERLAPPED属性
    localaddr.sin_addr.S_un.S_addr=INADDR_ANY;
    localaddr.sin_family=AF_INET;
    localaddr.sin_port=htons(PORT);

    //绑定监听套接字
    bind(sListen,(SOCKADDR*)&localaddr,sizeof(SOCKADDR));

    //监听
    listen(sListen,5);

    //创建服务线程
    CreateThread(NULL,0,ServerThread,NULL,NULL,NULL);
    
    while(1){
        int Addresslen=sizeof(SOCKADDR);

        //有连接到来
        sClient=accept(sListen,(SOCKADDR*)&clientaddr,&Addresslen);

        //将客户端套接字添加给全局socket数组
        MySockets[ConnectNum]=sClient;

        //创建一个自定义的结构并添加进全局数组
        MyOverData[ConnectNum]=(IO_OVERDATA*)HeapAlloc(GetProcessHeap(),
            HEAP_ZERO_MEMORY,sizeof(IO_OVERDATA));
        
        //指定缓冲区的大小
        MyOverData[ConnectNum]->Buffer.len=MSGSIZE;

        //给缓冲区分配空间
        MyOverData[ConnectNum]->Buffer.buf=(char*)HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,
            MSGSIZE);

        //为客户端的套接字创建事件对象
        MyOverData[ConnectNum]->overlap.hEvent=WSACreateEvent();

        //将事件对象添加进全局事件对象数组
        MyEvents[ConnectNum]=MyOverData[ConnectNum]->overlap.hEvent;

        //对套接字进行重叠操作
        WSARecv(sClient,&MyOverData[ConnectNum]->Buffer,1,&MyOverData[ConnectNum]->NumberOfBytesRecevd,
            &MyOverData[ConnectNum]->Flags,&MyOverData[ConnectNum]->overlap,NULL);
        
        //连接数量加一
        ConnectNum++;
    }


    closesocket(sListen);
    WSACleanup();
    return 0;
}

//线程函数
DWORD WINAPI ServerThread(LPVOID lpParam){
    
    //创建相关变量
    int ret,index;
    DWORD cbTransferred=0;

    while(1){
    
        //等待相关事件被设置为有信号状态
        ret=WSAWaitForMultipleEvents(ConnectNum,MyEvents,FALSE,1000,FALSE);
        
        //判断是否发生错误
        if(ret==WSA_WAIT_FAILED || ret==WSA_WAIT_TIMEOUT){
            if(ConnectNum==0)
                Sleep(1000);
            continue;

        }
        
        //获取对象在各个数组中的下表
        index=ret-WSA_WAIT_EVENT_0;
        
        //重置事件对象，将事件对象设置成无信号状态
        WSAResetEvent(MyEvents[index]);
        
        //获取在套接字上IO重叠操作的结果
        WSAGetOverlappedResult(MySockets[index],&MyOverData[index]->overlap,
            &cbTransferred,TRUE,&MyOverData[index]->Flags);
        
        //接收或发送的字节数为0，表示发生错误
        if(cbTransferred==0){
        
            //该函数用来销毁没有发送数据的套接字以及相关结构
            Cleanup(index);
        }
        else{
            
            //此处处理数据，在此作输出处理
            printf("%s\n",MyOverData[index]->Buffer.buf);
            memset(MyOverData[index]->Buffer.buf,0,MyOverData[index]->Buffer.len);
            
            //若是发送数据可在此处
            send(MySockets[index],"收到消息",strlen("收到消息")+1,0);
            
            //继续对套接字进行重叠操作，并立即返回
            WSARecv(MySockets[index],&MyOverData[index]->Buffer,1,
                &MyOverData[index]->NumberOfBytesRecevd,
                &MyOverData[index]->Flags,
                &MyOverData[index]->overlap,
                NULL);
        }
    }
    return 0;
}

//清理函数
void Cleanup(int index){

    //关闭套接字
    closesocket(MySockets[index]);

    //关闭事件对象
    WSACloseEvent(MyEvents[index]);

    //释放空间
    HeapFree(GetProcessHeap(),0,MyOverData[index]->Buffer.buf);
    HeapFree(GetProcessHeap(),0,MyOverData[index]);

    //将相关变量从全局数组中移除
    if(index<ConnectNum-1){
        MySockets[index]=MySockets[ConnectNum-1];
        MyEvents[index]=MyEvents[ConnectNum-1];
        MyOverData[index]=MyOverData[ConnectNum-1];
    }
    UINT temp=--ConnectNum;
    MyOverData[temp]=NULL;
    
}
```

关于上述程序需要做一些说明，其实上述程序并没有做到完全异步，比如accept()函数就有阻塞，在下下篇文章中会总结到完成端口模型，在完成端口模型中会用到AcceptEx()函数，而AcceptEx()函数也是异步的，那样的话就做到了完全异步。

另外一点需要注意的就是，可以发现在使用WSARecv()函数后，接收数据就不是在WSARecv()函数之后接收了，而是等到数据被拷贝到缓冲区后，相关事件被设置成有信号状态时才从缓冲区中得到数据。

运行截图如下：

![img](Windows_Socket_4_运行截图1.png)