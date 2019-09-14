---
title: 常用杀毒软件命令行
date: 2016-02-27 20:19:35
categories: [琐碎]
---
`<file_name>` 为被查杀文件的路径名。

`<result_file_name>`为存储结果日志的路径名。

### 卡巴斯基 2015

查杀指定文件：

`avp.com scan <file_name> > <result_file_name>`

病毒库升级：

`avp.com update`

日志文件导出：

`avp.com report /r:<result_file_name>`

启动文件监控（`<password>`为卡巴斯基的密码，需要自行在卡巴斯基的设置中进行设置，若没有密码则无法进行更改）：

`avp.com start File_Monitoring /password=<password>`

关闭文件监控：

`avp.com stop File_Monitoring /password=<password>`


### Avg Free 2016

查杀指定文件：

`avgscanx.exe /SCAN=<file_name> /REPORT=<result_file_name>`

病毒库升级：

`avgmfapx.exe /AppMode=UPDATE`

### Avast 高级版 11（免费版无命令行调用程序）

查杀指定文件：

`ashCmd.exe <file_name> /_ > <result_file_name>`

病毒库升级：

`ashUpd.exe vps`

### Dr.Web Security Space 11

查杀指定文件：

`dwscancl.exe <file_name> /RP:<result_file_name>`

病毒库升级：

`drwupsrv.exe -c update -l`

### Avira Free 15

小红伞的命令行调用需要额外下载 [scancl-win.zip](https://www.avira.com/en/download/product/avira-command-line-scanner-scancl)文件，下载完毕之后，需要将该压缩包中的文件拷贝到小红伞的安装目录下，一般情况下会提示没有权限，这个时候需要更改小红伞的自我保护选项。

查杀指定文件：

`scancl.exe <file_name> -l <result_file_name>`

病毒库升级：

`update.exe`

### Norton Security 22

查杀指定文件：

`Navw32.exe <file_name>`

日志导出：

`MCUI32.exe /export <result_file_name>`

病毒库升级：

`uiStub.exe /lu`

### Symantec Endpoint protection 12.1

查杀指定程序：

`DoScan.exe /ScanFile "<file_name>"`

DoScan查杀日志所在路径：

`C:\Programdata\Symantec\Symantec Endpoint Protection\[SEP Version]\Data\Logs\AV\`

病毒库升级：

`SepLiveUpdate.exe`

### ESET Nod32 9

查杀指定程序：

`ecls.exe /log-file <result_file_name> /files <file_name>`

病毒库升级：

`ecmd.exe /update`

### Mcafee

其本身不支持命令行查杀，可以使用其官方提供的另一工具vscl进行命令行查杀，相关信息见[这里](https://kc.mcafee.com/corporate/index?page=content&id=KB51141)。

从[这里](http://www.mcafee.com/apps/downloads/free-evaluations/default.aspx?region=us)下载程序，从[这里](http://www.mcafee.com/apps/downloads/security-updates/security-updates.aspx)下载病毒库，下载不带扩展名的那个，下载完毕之后将病毒库文件avvepo.zip中的avvdat.zip中的文件解压到vscl程序目录下，之后就可以使用scan.exe程序进行查杀了。
