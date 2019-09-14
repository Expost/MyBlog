---
title: Ubuntu网络监控工具
date: 2018-08-25 17:42:40
categories: [工具]
---

# nload

`nload`可以用来实时查看当前系统的流量信息，使用`apt install nload`命令安装后可直接使用，非常简单方便。

# nethogs

`nload`只能够查看系统所有程序的实时流量，无法查看每个进程的实时流量，这个时候就要使用nethogs这个工具了。使用`apt install nethogs`命令安装后就可直接使用了，也是非常简单方便。

# vnstat

该工具能够统计当前系统的所有流量信息，如果有自己的vps，可以使用这个工具统计vps使用的总流量，以与服务商给的数据做对比。

该工具的使用方法也很简单，按如下步骤即可：

1. 使用命令`apt install vnstat`进行安装。
2. 之后使用命令`vnstat -u -i eth0`设置要监控的网卡。
3. 使用命令`service vnstat stop` 停止vnstat服务。
4. 使用命令`chown vnstat:vnstat /var/lib/vnstat/.eth0`修改vnstat数据库目录的权限。
5. 再次使用`service vnstat start` 启动vnstat服务。
6. 使用如下命令查看统计的流量信息：
    1. `vnstat -l`, 查看实时流量。
    2. `vnstat -d`, 查看当天流量。
    3. `vnstat -m`, 查看当月流量。
