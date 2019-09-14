---
title: ubuntu使用rtl8723be无线网卡上网
date: 2015-02-03 22:59:04
categories: [琐碎]
---

我的电脑的型号是ThinkPad E540，使用的无线网卡是rlt8723be。刚买的时候默认安装的是ubuntu操作系统，那个时候上面安装的有无线网卡驱动，可以使用无线网卡上网。

后来我又重装了好多次操作系统，最后稳定下来的时候用的是xubuntu，但是xubuntu不提供无线网卡驱动，我上网找了找，也没有找到官方的驱动。最后在github上找到了一个驱动，但是编译安装后也是有一些问题，连上无线后总是会时不时的断掉。后来我也干脆不再用无线了。这次重装ubuntu后，发现ubuntu自动给我安装好了无线网卡驱动，但是还有上述问题，当连接一段时间后，还是突然会断掉。即使使用命令：`modprobe -r rtl8723be`和`modprobe rtl8723be`命令也是不行，必须要重新开机才好使。

于是我又重新上网找了找资料，最后发现了这一篇文章，很好的解决了问题。链接[在这里](https://forum.ubuntu.org.cn/viewtopic.php?f=116&t=462588&p=3109490)。楼主研究的很详细，在这里感谢楼主。

今天升级了一下ubuntu的内核，然后无线网卡又不好使了，只能连上我家的无线，连不上我邻居的，这让人很恼火。重新编译了网卡驱动后，好使了。

我把问题的具体解决方法记录下来，以后方便查看备忘。

```shell
//安装需要编译的东西
sudo apt-get install linux-headers-generic build-essential git

//下载网卡驱动源代码
git clone http://github.com/lwfinger/rtlwifi_new.git

//关闭网络
sudo service network-manager stop

//如果之前有驱动，则删除之，否则不必执行这一步
sudo modprobe -rfv rtl8723be

//编译安装新的网卡驱动
sudo make
sudo make install
sudo modprobe -v rtl8723be fwlps=0 ips=0

//重启
sudo reboot

//查看是否成功关闭fwlps=N，ips=N
systool -v -m rtl8723be

//如果上步查看fwlps和ips不是N，则执行这一步
echo "options rtl8723be ips=0 fwlps=0" | sudo tee /etc/modprobe.d/rtl8723be.conf
```
