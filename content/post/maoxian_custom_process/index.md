---
title: MaoXian web clipper插件裁剪结果自定义处理
date: 2020-03-25T00:42:35+08:00
categories: [琐碎]
---


# 背景

最近有将网页剪藏成markdown格式并在本地自定义处理的需求，研究了几个常用的[剪藏插件](https://renyili.org/post/backup_web_pages/)。最终认为[Maoxian Web Clipper](https://chrome.google.com/webstore/detail/maoxian-web-clipper/kjahokgdcbohofgdidndeiaigkehdjdc)插件比较满足自己的需求。

Maoxian插件可以直接将剪藏的网页下载到浏览器的下载目录下，并按照一定的目录结构进行存储。这里有一个麻烦点，即保存的目录是在浏览器的下载目录下的，与浏览器下载的其他文件搅合在一起，不方便管理。

为此Maoxian插件提供了一个本地程序，可以将剪藏的结果存放到其他地方，同时还提供了对剪藏历史的管理功能。这个本地程序使用ruby实现，采用native messaging的方式与浏览器进行通信。

自己需要对剪藏下来的markdown格式的文件做一些自定义处理，而这些功能无法通过maoxian插件本身实现，但经过研究，发现可以利用这个本地程序与插件的交互机制来实现结果的自定义处理。

# 本地程序介绍

首先需要参考[官方说明](https://mika-cn.github.io/maoxian-web-clipper/native-app/index-zh-CN.html)安装本地程序。**我的环境是Windows+Chrome，以下说明以此环境为准**。

在运行本地程序目录下的`install.bat`程序后，会把配置`manifest.json`写到注册表中，在`manifest.json`中配置了与插件关联的本地程序路径，以及与本地程序通信的方式（目前只有stdio这一种方式）。这里配置的本地程序路径是目录下的`app_loader.bat`，而该bat中实际执行的是ruby代码`main.rb`。

虽然不会ruby，但大致看一下也能了解其含义，与浏览器插件的通信逻辑主要在`lib\application.rb`文件中。消息的接收和发送代码则在`lib\native_message.rb`文件中。通过注释可以了解到上下行协议格式很简单。

```ruby
# 32位的长度 + utf8编码的json数据
32bit(message length) + message(utf8 encoded json)
```

通信过程中，本地程序作为服务端运行，由浏览器插件向本地程序发送请求，本地程序执行相应操作后，返回结果。

传递的json数据可以在开启程序的debug模式后从log中查看，开启debug的方式是修改`config.yaml`配置中的`environment`字段为`development`。

浏览器会向本地程序发送6种类型的请求，分别是：

1. get.version，获取本地程序版本号。
2. get.downloadFolder，获取配置中指定的文件保存目录。
3. download.text，下载剪藏文本。插件会将文本数据传递给本地程序，由本地程序存储到配置指定的目录下。这里的文本包括剪藏的html或是markdown文本。
4.  download.url，下载链接。插件将剪藏文本中的图片链接给到本地程序，由本地程序下载之后保存。
5.  clipping.op.delete，删除剪藏结果。
6.  history.refresh，刷新剪藏历史。

如果会ruby，那么直接修改本地程序的代码即可满足自己的需求，然而自己并不会ruby，查了下Python也有native messaging通信的[库](https://pypi.org/project/nativemessaging/)，看了下用法，使用起来也很简单，既然通信的协议知道了，收发包也支持了，那干脆自己实现一个伪本地程序好了。

# 实现

简单实现的python代码如下，

```python
import os
import logging
import requests
import nativemessaging

root = "C:\\Users\\pc\\Desktop"

log = logging.getLogger("log")
log.setLevel(level = logging.INFO)
formatter = logging.Formatter("[%(asctime)s] %(message)s")
file_handler = logging.FileHandler("main.log", mode="a")
file_handler.setFormatter(formatter)
log.addHandler(file_handler)

# 发送消息
def send_msg(msg):
    encode_msg = nativemessaging.encode_message(msg)
    nativemessaging.send_message(encode_msg)

# 发送下载成功消息
def response_download_success(msg, filename):
    data = {"type":msg["type"], "filename":filename, "taskFilename":msg["filename"], "failed":False}
    send_msg(data)

# 发送下载失败消息    
def response_download_failed(msg, filename, errmsg):
    data = {"type":msg["type"], "filename":filename, "taskFilename":msg["filename"], "failed":True, "errmsg": errmsg}
    send_msg(data)

def http_download(msg):
    url = msg["url"]
    timeout = msg["timeout"]
    try:
        req = requests.get(url = url, timeout = timeout)
        if req.status_code == 200:
            return req.content
    except Exception:
        log.info("download %s failed", url)
    return b''
    
# 保存文本
def download_text(msg):
    path = os.path.join(root, msg["filename"])
    if msg["taskType"] == "mainFileTask":
        dir = os.path.dirname(path)
        if not os.path.isdir(dir):
            os.makedirs(dir)
        content = msg["text"]
        with open(path, "w", encoding="utf8") as f:
            f.write(content)
        response_download_success(msg, path)
    elif msg["taskType"] == "infoFileTask":
        response_download_success(msg, path)
    else:
        response_download_success(msg, path)

# 保存url（图片）
def download_url(msg):
    content = http_download(msg)
    path = os.path.join(root, msg["filename"])
    if content:
        dir = os.path.dirname(path)
        if not os.path.isdir(dir):
            os.makedirs(dir)
        with open(path, "wb") as f:
            f.write(content)
        response_download_success(msg, path)
    else:
        response_download_failed(msg, path, "downlaod %s failed" %path)

while True:
    # 循环接收消息
    msg = nativemessaging.get_message()
    log.info(str(msg))
    if msg["type"] == "get.version":
        send_msg({"type": msg['type'], "version": "0.2.2"})
    if msg["type"] == "get.downloadFolder":
        send_msg({"type": msg['type'], "downloadFolder": root})
    if msg["type"] == "download.text":
        download_text(msg)
    if msg["type"] == "download.url":
        download_url(msg)
```

将程序保存成`main.py`，之后修改本地程序目录中的`app_loader.bat`中的命令为`python "%~dp0/main.py" %*`。重启浏览器运行，先查看设置中本地程序的状态是否正常。正常的话，便可正常剪藏网页。

由于自己是为了给剪藏下来的结果进行自定义处理，因此并不需要删除剪藏结果以及刷新历史功能，所以上面的代码中并未实现这些功能。

接下来只需在下载文本函数那里添加自己想要的自定义逻辑就行了，比如按照自己的想法设置目录结构，或是对下载下来的文本进行一些修改后再进行保存等。这里需要注意一点，本地程序保存网页时，网页中的图片是需要由本地程序重新下载的，这个可能会因各种原因导致下载失败，之前已经问过作者是否会支持获取浏览器中缓存的图片，作者表示后续会做的（参见[issue 103](https://github.com/mika-cn/maoxian-web-clipper/issues/103)），期待新版本😍。

# 总结

自己对MaoXian这个插件还是很满意的，剪藏效果好，同时还可以自己模拟实现本地程序，进而满足自己定制化的需求。如果哪天自己不用印象笔记了，可以自己实现一个网页备份服务，搭建在自己的服务器上，与自己的伪本地程序以及MaoXian插件进行联动😂。

# 参考文章

1. [Native Messaging](https://developer.chrome.com/extensions/nativeMessaging)
2. [pypi nativemessaging](https://pypi.org/project/nativemessaging/)