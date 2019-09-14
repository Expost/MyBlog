---
title: 使用树莓派做无线路由中继站
date: 2015-05-11 00:10:34
categories: [硬件]
---

玩树莓派的灵感来自于老油条的翻墙路由器。他前段时间买了个路由器，然后刷了openwrt的固件，专门用来做翻墙路由器。而我之前买了搬瓦工的vps，然后配了个shadowsocks，但是发现用学校的电信网使用这个shadowsocks的速度并不快，但是，使用cmcc-edu后，发现翻墙网速挺快的，在youtube上看720p的视频，毫无压力。因此，买这个树莓派后，就想用树莓派连上cmcc-edu，然后再建个shadowsocks代理，然后再分享无线，这样的话，就做成了一个翻墙速度相当快的路由器。但是到目前为止，并没有实现代理，所以，目前也就相当于搞了个中继站。

openwrt官方有树莓派2的固件，但是貌似只有源代码，需要自行编译。网上找到一篇[教程(OPENWRT ON ARM-BASED PLATFORM (RASPBERRY PI 2))](http://dab-embedded.com/en/blogs/openwrt-on-arm-based-platform-raspberry-pi-2/)，讲如何编译固件并进行安装的。我编译的时候出现问题，后来发现那个教程的下面有编译好的固件，下下来刷上后，感觉固件有问题（也可能是我不会玩）。后来也就不了了之了。

主要参考[这篇文章](http://www.embbnux.com/2015/02/08/setup_raspberry_to_wifi_access_point_with_rtl8188/)。

参考的文章主要介绍怎么把树莓派做成一个无线路由器，是有线到无线，而要做成一个无线路由器中继站的话，就是无线到无线的。

下面做下搬运工。

我用的两个无线网卡的驱动分别是RTL8188CUS和RTL8192CU。

先安装udhcpd。
```shell
sudo apt-get install udhcpd
```

然后编辑配置文件/etc/udhcpd.conf
```shell
start 192.168.8.100 #配置网段
end 192.168.8.150
interface wlan1 # The device uDHCP listens on.
remaining yes
opt dns 192.168.1.1 8.8.8.8
opt subnet 255.255.255.0
opt router 192.168.8.1 # 无线lan网段
opt lease 864000 # 租期10天
```

编辑/etc/default/udhcpd注释掉下面这句话
```shell
# Comment the following line to enable
#DHCPD_ENABLED="no"
```

编辑/etc/network/interfaces，进行如下配置
```shell
auto lo
iface lo inet loopback
#有线网卡就dhcp
iface eth0 inet dhcp
#无线网卡1的配置我没有动，他主要用来进行接收cmcc-edu无线
#因为cmcc-edu连接不需要密码而是用web页面登陆的
#如果要想接收其他路由器的wifi，可以更改设置为：
#iface wlan0 inet dhcp
#    wpa-ssid Your_Wifi_SSID
#    wpa-psk Your_Wifi_Password
iface wlan0 inet manual
wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf
iface default inet dhcp

#无线网卡2用来发射无线信号，这里设置成静态的ip地址
allow-hotplug wlan1
iface wlan1 inet static
        address 192.168.8.1
        netmask 255.255.255.0
```

接下来安装hostapd，并配置。网上的一些教程中都没有使用官方的hostapd，主要是因为官方的不支持他们的网卡rtl8188cus，由于我使用的无线网卡也是rtl8188cus，所以我这里也没有使用官方的hostapd。

下载hostapd源码并安装。
```shell
git clone git@github.com:jenssegers/RTL8188-hostapd.git
cd hostapd
make
sudo make install
```

安装之后，修改配置/etc/hostapd/hostapd.conf
```shell
interface=wlan1
ssid=MYWIFI_EMBBNUX #wifi名
channel=8
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=3
wpa_passphrase=12345678 #WIFI密码
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
driver=rtl871xdrv
ieee80211n=1
hw_mode=g
device_name=RTL8192CU
manufacturer=Realtek
```

编辑/etc/default/hostapd,添加：
```shell
DAEMON_CONF="/etc/hostapd/hostapd.conf"
```

配置NAT：
```shell
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
```

编辑/etc/sysctl.conf，取消下面这一句的注释
```shell
net.ipv4.ip_forward=1
```

启用NAT，将来自wlan0的包转发到wlan1上：
```shell
sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
sudo iptables -A FORWARD -i wlan0 -o wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan1 -o wlan0 -j ACCEPT
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
```

编辑/etc/network/interfaces，添加：
```shell
up iptables-restore < /etc/iptables.ipv4.nat
```

启用热点服务
```shell
sudo service hostapd start
sudo service udhcpd start
```

这个时候已经可以看到热点了。

接下来设置hostapd和udhcpd服务的自启动。
```shell
sudo update-rc.d hostapd enable
sudo update-rc.d udhcpd enable
```

使用的时候，先连上树莓派的热点，然后ssh192.168.8.1（树莓派的地址），然后使用vncserver建立远程桌面，打开桌面版的wifi连接程序，连接cmcc-edu，之后再打开浏览器，进行登陆。登陆之后，笔记本就可以连接外网了。翻墙的话，还是使用pc上的shadowsocks客户端。表示使用浏览器登陆很麻烦，但是暂时想不到好的办法。cmcc-edu登陆的时候需要输入验证码，所以使用文本浏览器登陆就行了。也想过写一个脚本进行登陆，但是同样被验证码给阻拦了，我也试了试网上的一些识别方法，但是效果非常不理想。

关于使用代理这点，我知道关键就在包转发那里，但是暂时对iptables的设置还不熟悉，上面的是直接搬运更改的，所以暂时就先搁浅吧，等熟悉后，我再更新。
