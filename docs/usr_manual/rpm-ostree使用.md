# rpm-ostree使用

## rpm-ostree安装软件包

安装wget

```
rpm-ostree install wget
```

![image-20211014201905155](/docs/graph/rpm-ostree使用/image-20211014201905155.png)

重启系统,可在启动时通过键盘上下按键选择rpm包安装完成后或安装前的系统状态，其中【ostree:0】为安装之后的版本。

```
systemctl reboot
```

![image-20211014201914711](/docs/graph/rpm-ostree使用/image-20211014201914711.png)

查看wget是否安装成功

```
rpm -qa | grep wget
```

![image-20211014201922069](/docs/graph/rpm-ostree使用/image-20211014201922069.png)

## rpm-ostree 手动更新升级 NestOS

在NestOS中执行命令可查看当前rpm-ostree状态，可看到当前版本为LTS.20210927.dev.0

```
rpm-ostree status
```

![image-20211014201929746](/docs/graph/rpm-ostree使用/image-20211014201929746.png)

执行检查命令查看是否有升级可用，发现存在LTS.20210928.dev.0版本

```
rpm-ostree upgrade --check
```

![image-20211014201940141](/docs/graph/rpm-ostree使用/image-20211014201940141.png)

预览版本的差异

```
rpm-ostree upgrade --preview
```

![image-20211014201948988](/docs/graph/rpm-ostree使用/image-20211014201948988.png)

可以看到，在0928的最新版本中，我们将wget包做了引入。
下载最新的ostree和RPM数据，不需要进行部署

```
rpm-ostree upgrade --download-only
```

![image-20211014201956536](/docs/graph/rpm-ostree使用/image-20211014201956536.png)

重启NestOS，重启后可看到系统的新旧版本两个状态,选择最新版本的分支进入

```
rpm-ostree upgrade --reboot
```

## 比较NestOS版本差别

检查状态，确认此时ostree有两个版本,分别为LTS.20210927.dev.0和LTS.20210928.dev.0

```
rpm-ostree status
```

![image-20211014202004110](/docs/graph/rpm-ostree使用/image-20211014202004110.png)

根据commit号比较2个ostree的差别

```
rpm-ostree db diff 55eed9bfc5ec fe2408e34148
```

![image-20211014202014370](/docs/graph/rpm-ostree使用/image-20211014202014370.png)

## 系统回滚

当一个系统更新完成，之前的NestOS部署仍然在磁盘上，如果更新导致了系统出现问题，可以使用之前的部署回滚系统。

### 临时回滚

要临时回滚到之前的OS部署，在系统启动过程中按住shift键，当引导加载菜单出现时，在菜单中选择相关的分支。

### 永久回滚

要永久回滚到之前的操作系统部署，登录到目标节点,运行rpm-ostree rollback，此操作将使用之前的系统部署作为默认部署，并重新启动到其中。
执行命令，回滚到前面更新前的系统。

```
rpm-ostree rollback
```

![image-20211014202023177](/docs/graph/rpm-ostree使用/image-20211014202023177.png)

重启后失效。

## 切换版本

在上一步将NestOS回滚到了LTS.20210927.dev.0版本，可以通过命令切换当前 NestOS 使用的rpm-ostree版本，将LTS.20210927.dev.0切换为LTS.20210928.dev.0版本。

```
rpm-ostree deploy -r LTS.20210928.dev.0
```

![image-20211014202030442](/docs/graph/rpm-ostree使用/image-20211014202030442.png)

重启后确认目前NestOS已经使用的是LTS.20210928.dev.0版本的ostree了。

![image-20211014202037703](/docs/graph/rpm-ostree使用/image-20211014202037703.png)

