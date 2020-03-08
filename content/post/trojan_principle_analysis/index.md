---
title: Trojan原理简单分析
date: 2020-03-07 17:42:40
categories: [工具]
---

# 背景

偶然听说了[trojan](https://github.com/trojan-gfw/trojan)这个扶墙工具，了解到它跟v2ray的ws+tls的方式类似，都使用了真正的https，这点跟我的喜好相符，个人以为最稳的扶墙方式便是这种真实https的方式，倘若自己再有一个网站，隐藏在网站后面，那真的是非常非常的稳。

由于自己对这种扶墙方式比较感兴趣，所以希望了解下其实现的原理，先前有大概瞟过v2ray的源码，但它的源码比较复杂，没有深入去看，而trojan的源码则简单一些。

# trojan使用

在阅读源码之前，先要了解下trojan的用法，通过用法对其实现方法有个大概的猜想。我没有根据官网的说明一点点搭建，而是直接网上找了一个一键安装脚本，安装完之后，在可用的情况下再去阅读配置，进而反推出trojan具体如何使用。

经过研究以及阅读网上相关的资料后，发现trojan和v2ray还是有些不一样的。区别如下图。

![](./Image1.png)

v2ray的tls+ws模式是挂在网站后面的，客户端流量来了后，先经过http服务器，比如nginx，nginx根据请求的http路径来判断是否要转发流量给v2ray。由于先经过nginx，因此可以在这里部署多个网站，v2ray只作为一个后台运行的小透明。

而trojan则不同，客户端流量来了后，先经过trojan。trojan判断流量包头是否是合法的Trojan请求头，如果是，则进行代理转发，如果不是，则通过配置中定义的ip和端口进行转发，这里一般是转发给http服务器。

虽然从效果上来说，这两者是一样的，但trojan这种方式有个蛋疼点，即如果要在代理服务器上搭建多个域名的https网站会稍微麻烦些，因为trojan不支持对不同域名直接进行分发。通过查看[issuse131](https://github.com/trojan-gfw/trojan/issues/131)、[issuse245](https://github.com/trojan-gfw/trojan/issues/245)了解到，需要通过haproxy或是nginx preread模块的方式解决。相较于v2ray，trojan的成本要稍微高一些。

另外，v2ray还有的一个好处，它使用CDN的成本很低，而通过了解trojan的[issue70](https://github.com/trojan-gfw/trojan/issues/70)、[issue94](https://github.com/trojan-gfw/trojan/issues/94)，要使用CDN需要付出一定的成本（具体我还未搞明白）。

# 代理过程

大概看了下trojan的源码，trojan使用C++实现，网络库方面使用了boost的asio库，自己并不会用asio库，不过从其API还是能大概猜出其含义。

整体来说，trojan的源码比较简单，各个模块之间的划分很清晰，很容易的就找到了网络传输的核心代码。在trojan中，不同的网络功能使用session的概念来说明，在代理模式下，客户端的逻辑实现在clientsession中，而服务端的逻辑实现在serversession中。

它的通信流程大致如下。

![](./Image2.png)

从这张图中可以看出，trojan的客户端和服务端其实都在同时充当客户端和服务端。PC的浏览器向trojan客户端进行请求，trojan客户端对接受到的浏览器数据进行tls加密，之后发送到墙外的trojan服务端，trojan服务端将流量进行解密，之后再转发给真正的服务器。请求到数据之后，数据再原路返回。

在客户端与服务端之间传输数据时，使用的是tls加密，这点在代码中靠asio库支持，自己不熟，不做说明。

trojan的协议也比较简单，浏览器与trojan客户端之间使用socks5协议，而trojan客户端与trojan服务端之间使用自定义的协议，官方文档上已经有相应的说明，这里再粘贴一下。

```cpp
+-----------------------+---------+----------------+---------+----------+
| hex(SHA224(password)) |  CRLF   | Trojan Request |  CRLF   | Payload  |
+-----------------------+---------+----------------+---------+----------+
|          56           | X'0D0A' |    Variable    | X'0D0A' | Variable |
+-----------------------+---------+----------------+---------+----------+

where Trojan Request is a SOCKS5-like request:

+-----+------+----------+----------+
| CMD | ATYP | DST.ADDR | DST.PORT |
+-----+------+----------+----------+
|  1  |  1   | Variable |    2     |
+-----+------+----------+----------+

where:

    o  CMD
        o  CONNECT X'01'
        o  UDP ASSOCIATE X'03'
    o  ATYP address type of following address
        o  IP V4 address: X'01'
        o  DOMAINNAME: X'03'
        o  IP V6 address: X'04'
    o  DST.ADDR desired destination address
    o  DST.PORT desired destination port in network octet order
```

trojan客户端发起的每个连接中，头部都是上面结构所示的那样，其中，

1. 头部最开始是56字节的hash，这个hash是配置中设置的字符串密码计算出来的hash值。
2. hash之后跟CRLF换行符。
3. CRLF后是TrojanRequest的结构。
4. TrojanRequest后又是一个CRLF换行符。
5. CRLF之后便是真正的数据。

`TrojanRequest`结构与`socks5`协议类似，说明如下。

1. 首先是`CMD`字段，占用1字节，分别有`CONNECT`和`UDP ASSOCIATE`这两种含义。
2. 之后是`ATYP`字段，占用1个字节，分别表示`ipv4`、`domain name`和`ipv6`这3种连接方式。
3. 之后是`DST.ADDR`，长度不定，由`ATYP`决定，用来表示请求的目标地址。
4. 最后是`DST.PORT`，占用2个字节，用来表示请求的端口。

数据的传输完全使用的是asio异步传输的方式，异步的方式稍微有点难看懂，下面是整理的TCP请求过程图。

![](./Image3.png)

整个过程比较简单，唯一一点需要关注的是，服务端Trojan在收到客户端Trojan的第一条数据后，会首先校验TrojanRequest头中的hash字段是否与服务端中存储的一致，如果不一致，则服务端认为这不是合法的trojan代理请求，之后会直接将它转发到http服务器中。如果是墙主动连接探测，那么肯定是非法的trojan代理请求，之后请求被转发到http服务器，在墙看来，这就是一个正常的http服务器，不会发现异常。

上面只分析了TCP的流程，UDP的暂不关注，后面有空再补充。

# 其他

在官方文档的配置部分，除了客户端和服务端的配置外，还有forward和nat这两种功能的配置，在代码中，forward功能对应forwardsession，而nat功能对应natsession，这里也对它们进行简单的说明。

## forward

forward，顾名思义，是用来进行端口转发的。在forward的配置中多了两个字段，分别是`target_addr`和`target_port`，用来指定目标地址和端口。它的流程可用下图说明。

![](./Image4.png)

注意红字的说明，在Trojan服务端这里，请求的不再是要访问的Google/Youtube这类网站，而是由`target_addr`和`target_port`指定的地址。

如果外网的某个固定的服务被墙了，无法访问，那么便可以使用这种模式来进行加密中转访问。

## nat

nat模式用于透明代理，一般场景是在路由器上，通过iptables设置规则将路由器上外发的所有的流量重定向到某个端口上，这个端口由nat模式的trojan客户端监听，nat模式的trojan客户端在接收到数据后，通过`getsockopt(fd, SOL_IP, SO_ORIGINAL_DST, &destaddr, &socklen);`得到流量要发往的真正地址`target_addr`和端口`target_port`。

接下来就和forward模式一样，先将流量发往墙外的服务端trojan，服务端trojan再根据`target_addr`和`target_port`将流量进行转发。

# 总结

trojan的实现比较简单，原理也很可靠，是一款可靠的扶墙工具。不过由于其不容易兼容多个https网站，且目前各个平台的客户端程序不够完善，因此暂时还是更加偏向于v2ray。

后续有时间，再了解下v2ray tls+ws模式的实现。

# 参考连接

1. [Trojan Document](https://trojan-gfw.github.io/trojan/)。
2. [使用策略路由实现涉及getsockopt(…, SO_ORIGINAL_DST, …)程序的远程调用（Redsocks, ss-redir之类的远程调用）](https://zhensheng.im/2017/08/22/%E4%BD%BF%E7%94%A8%E7%AD%96%E7%95%A5%E8%B7%AF%E7%94%B1%E5%AE%9E%E7%8E%B0%E6%B6%89%E5%8F%8Agetsockopt-so_original_dst-%E7%A8%8B%E5%BA%8F%E7%9A%84%E8%BF%9C%E7%A8%8B%E8%B0%83%E7%94%A8%EF%BC%88r.meow.html)。
3. [你也能写个 Shadowsocks ](https://github.com/gwuhaolin/blog/issues/12)。