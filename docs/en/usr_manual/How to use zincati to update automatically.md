# How to use zincati to update automatically

Zincati is responsible for the automatic update of NestOS. zincati checks whether the current updatable version is available through the backend provided by cincinnati. If a new version is detected, it will be downloaded through RPMS -ostree.

The zincati automatic update service is disabled by default. You can modify the configuration file to enable the automatic update service upon startup.

```
vi /etc/zincati/config.d/95-disable-on-dev.toml
```

Set updates.enabled to true
Add a configuration file to modify the cincinnati back-end address

```
vi /etc/zincati/config.d/update-cincinnati.toml
```

Add the following

```
[cincinnati]
base_url="http://nestos.org.cn:8080"
```

Restart the zincati service

```
systemctl restart zincati.service
```

When a new version is available, zincati automatically detects the updatable version. Check the rpm-ostree status. The status is busy, indicating that the system is being upgraded.

![蓝信图片_0880c4c80710ab88d007](/docs/zh/graph/zincati自动更新使用/0880c4c80710ab88d007.png)

After a period of time, NestOS automatically restarts. Log in to NestOS again and confirm the status of rpm-ostree. The status changes to idle and the current version is 20211013, indicating that the rpm-ostree version has been upgraded.

![0880c4c80710abc840](/docs/zh/graph/zincati自动更新使用/0880c4c80710abc840-1634214176877.png)

View zincati service logs to confirm the upgrade process and system restart logs. In addition, the "auto-updates logic enabled" message in the log indicates that the updates are automatic.

![0880c4c80710abca0b](/docs/zh/graph/zincati自动更新使用/0880c4c80710abca0b.png)
