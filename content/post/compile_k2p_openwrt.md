---
title: 自编译K2P OpenWrt固件
date: 2020-06-25T23:37:55+08:00
categories: [杂乱技术]
---

# 背景

最近搬家，换了天威宽带，天威宽带很不错，直接给了自己之前一直心心念的公网IP，但接入网络后，发现某些网站打开很慢，比如简书、知乎、淘宝等。

一开始的想法是DNS哪里出了问题，于是在自己电脑上设置用114或是中科大的dns，问题依旧。自己的网络结构是k2p主路由加虚拟机中的koolshare openwrt旁路由，后来想着直接用主路由试一下，发现那些问题都消失了，主路由使用的是天威自己的dns。加上openwrt旁路由后，没有对其做任何的dns设置，按道理来说应该使用的是天威自己的dns，但就是有访问慢的问题。尝试在自己电脑上设置天威dns也不行，最终决定不再使用openwrt旁路由，直接使用k2p主路由。

k2p上安装的一直是hiboy大佬的老毛子固件，之前使用openwrt旁路由的主要原因是感觉老毛子的科学插件不够稳定，有时候同一个节点，电脑可以正常科学上网，但使用路由器就不行。也由于这个原因，现在单独使用k2p也不太可行，因此决定换用其他固件。

网上搜了一圈，看到Lean大佬的openwrt系统评价很高，于是决定尝试一下，在恩山搜到了L大编译的最新版本的固件，是20年3月的版本，试用了一圈，基本非常满意。

科学上网功能相当稳定，自己需要的cloudflare ddns服务也能支持（通过安装软件包），提供的网易云音乐解锁功能也非常棒。但唯一一点不满意的是，科学上网插件中提供的sock5代理功能并不支持通过路由器上的节点科学上网，只能访问国内网站，它只是单纯的一个sock5代理。而这个功能对我来说也比较重要，因此，最终还是想换个其他大佬编译的lean版本openwrt，看能否提供我想要的这个功能。

后面又尝试了一下，发现最新的代码编译出的固件已经修复了这个问题，于是想着自己也尝试编译一下。

# 编译

编译这块参考了[官方文档](https://github.com/coolsnowwolf/lede)以及简书上的这篇[文章](https://www.jianshu.com/p/eed71e8a22cc)，整体来说编译过程并不复杂，但还是有些坑要注意。

1. 编译环境很重要，自己一开始为了省事，直接使用的Windows的WSL，但都无法编译通过，后来使用了虚拟机中的Ubuntu LTS 18.06才编译过。
2. K2P的flash只有16M，实际能用的还要更小一些，因此插件一定不能过多，仅选择自己需要的插件即可，否则编译的固件太大，没办法安装。

编译步骤如下：

1. 首先确保编译环境全程可以科学上网。
2. 更新源，`sudo apt-get update`。
3. 安装编译固件所需要的工具，`sudo apt-get -y install build-essential asciidoc binutils bzip2 gawk gettext git libncurses5-dev libz-dev patch python3.5 python2.7 unzip zlib1g-dev lib32gcc1 libc6-dev-i386 subversion flex uglifyjs git-core gcc-multilib p7zip p7zip-full msmtp libssl-dev texinfo libglib2.0-dev xmlto qemu-utils upx libelf-dev autoconf automake libtool autopoint device-tree-compiler g++-multilib antlr3 gperf wget`。
4. 克隆代码，`git clone https://github.com/coolsnowwolf/lede`，之后进入到`lede`目录。
5. 编辑`feeds.conf.default`文件，删除最后`helloworld`一行前的`#`号，并保存。
6. 执行命令`./scripts/feeds update -a`和`./scripts/feeds install -a`。
7. 执行命令`make menuconfig`进行配置。对于k2p来说，自己修改的内容有这些：
   1. `Target System` 选择`MediaTek Ralink MIPS`
   2. `Subtarget`选择`MT7621 based boards`
   3. `Target Profile`选择`Phicomm K2P`
   4. `LuCI->Applications`下选择的插件有：
      1. accesscontrol
      2. adbyby-plus
      3. arpbind
      4. autoreboot
      5. ddns
      6. filetransfer
      7. firewall
      8. flowoffload
      9. mtwifi
      10. nlbwmon
      11. ramfree
      12. ssr-plus，Shadowsocks v2ray plugin，Trojan，Redsocks2，ShadowsocksR Server
      13. unblockmusic，unblockmusic golang version
      14. upnp
      15. vlmcsd
      16. wol
      17. zerotier
8. 使用命令`make -j8 download V=s`下载dl库。
9. 输入 `make -j1 V=s`开始编译，其中`-j1`中的1是编译时的线程数，第一次编译时推荐使用1，如果有什么错误可以方便查看。

最终编译完的固件在目录`lede/bin/targets`中。

如果后面需要调整选项重新编译，那么执行下面命令即可。

1. 进入lede目录，使用命令`git pull`更新源码。
2. 执行命令`./scripts/feeds update -a && ./scripts/feeds install -a`。
3. 使用命令`rm -rf ./tmp && rm -rf .config`删除旧的配置。
4. 使用命令`make menuconfig`重新配置编译选项。
5. 使用命令`make -j$(($(nproc) + 1)) V=s`进行编译。

使用2020-05-24日的代码，以及上面的插件列表，最终编译出的k2p的固件大小是14M，满足要求。

在上面的插件中我没有添加v2ray，添加之后固件就会超出限制。看L大以及其他一些大佬编译的固件功能很全，但大小也没有超出限制，不清楚他们对代码做了什么优化，只知道对v2ray进行了upx压缩，后面有空可以再研究下。

目前已经安装了自己编译的固件，整体比较稳定，科学上网、ddns、解锁网易云等功能也都满足自己的要求，但在使用过程中会发现某些时候请求dns会失败，导致有时候网页需要多刷新几遍才能打开，后来测试发现是天威自己的DNS服务器太垃圾，换用114后就没有这个问题了。
