# zincati自动更新使用

zincati负责NestOS的自动更新，zincati通过cincinnati提供的后端来检查当前是否有可更新版本，若检测到有可能新版本，会通过rpm-ostree进行下载。

目前系统默认关闭zincati自动更新服务，可通过修改配置文件设置为开机自动启动自动更新服务。

```
vi /etc/zincati/config.d/95-disable-on-dev.toml
```

将updates.enabled设置为true
同时增加配置文件，修改cincinnati后端地址

```
vi /etc/zincati/config.d/update-cincinnati.toml
```

添加如下内容

```
[cincinnati]
base_url="http://nestos.org.cn:8080"
```

重新启动zincati服务

```
systemctl restart zincati.service
```

当有新版本时，zincati会自动检测到可更新版本，此时查看rpm-ostree状态，可以看到状态是“busy”，说明系统正在升级中。

![蓝信图片_0880c4c80710ab88d007](/docs/graph/zincati自动更新使用/0880c4c80710ab88d007.png)

一段时间后NestOS将自动重启，此时再次登录NestOS，可以再次确认rpm-ostree的状态，其中状态转为"idle"，而且当前版本已经是“20211013”，这说明rpm-ostree版本已经升级了。

![0880c4c80710abc840](/docs/graph/zincati自动更新使用/0880c4c80710abc840-1634214176877.png)

查看zincati服务的日志，确认升级的过程和重启系统的日志。另外日志显示的"auto-updates logic enabled"也说明更新是自动的。

![0880c4c80710abca0b](/docs/graph/zincati自动更新使用/0880c4c80710abca0b.png)
