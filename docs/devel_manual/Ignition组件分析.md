# Ignition组件分析



Ignition版本：v2.14

github地址：https://github.com/coreos/ignition.git

NestOS集成了配置工具Ignition，当用户部署配置一个NestOS系统时，需要准备一份自定义的ignition配置文件（点火文件），系统首次启动引导阶段通过Ignition组件来完成配置。Nestos旨在作为不可变的基础架构进行管理，即当机器部署完毕初始化配置完成后，不应该对其进行重新配置。如果需要变更配置，则需要使用新的ignition配置文件重新部署。大规模集群部署时，使用相同的ignition配置文件，可以很方便的对机器进行扩展。下面对于Ignition组件的特性及代码结构来进行简要的阐述。

### 一、概述-what is Ignition

Ignition是一个配置实用程序，可以读取JSON格式的配置文件，该配置文件的组件包括：创建用户、添加受信的SSH密钥，启动systemd服务等等。

Ignition只在系统第一次启动时运行（在initramfs期间），因为Ignition在引导过程的早期阶段运行，所以可以在用户空间开始引导之前对磁盘进行重新分区、格式化文件系统、创建用户和写入文件。并且在systemd开始之前systemd服务已经写入了磁盘，加快了引导时间。Ignition 运行时，它会在给定环境的命名位置中查找配置数据，例如文件或 URL，并在switch_root调用之前将其应用于机器以转至机器的根文件系统。

#### 1.1 配置过程

为了方便使用者读、写，Ignition文件增加了一步转换过程

1）编写Butane config（yaml格式）

2）将Butane config转换成Ignition config（json格式）

3）使用生成的Ignition config引导新的NestOS镜像

```
#Butane配置转换成Ignition配置
podman run --interactive --rm quay.io/coreos/butane:release --pretty --strict < your_config.bu > transpiled_config.ign
```

### 二、功能-What can Ignition do？

#### 1.1 配置示例

- 启动服务

Ignition配置示例服务内容：

```
{
  "ignition": { "version": "3.0.0" },
  "systemd": {
    "units": [{
      "name": "example.service",
      "enabled": true,
      "contents": "[Service]\nType=oneshot\nExecStart=/usr/bin/echo Hello World\n\n[Install]\nWantedBy=multi-user.target"
    }]
  }
}
```

example.service

```
[Service]
Type=oneshot
ExecStart=/usr/bin/echo Hello World

[Install]
WantedBy=multi-user.target
```

- 修改服务

​	此配置将添加一个systemd unit插件来修改现有服务systemd-journald.service并将其环境变量SYSTEMD_LOG_LEVEL设置为debug

```
{
  "ignition": { "version": "3.0.0" },
  "systemd": {
    "units": [{
      "name": "systemd-journald.service",
      "dropins": [{
        "name": "debug.conf",
        "contents": "[Service]\nEnvironment=SYSTEMD_LOG_LEVEL=debug"
      }]
    }]
  }
}
```

`systemd-journald.service.d/debug.conf`:

```
[Service]
Environment=SYSTEMD_LOG_LEVEL=debug
```

- 在根文件系统上创建文件

此示例将单个文件写入/etc/someconfig根文件系统

```
{
  "ignition": { "version": "3.0.0" },
  "storage": {
    "files": [{
      "path": "/etc/someconfig",
      "mode": 420,
      "contents": { "source": "data:,example%20file%0A" }
    }]
  }
}
```

Ignition还可对以下场景进行配置，具体信息请参阅[配置示例]([Example Configs - coreos/ignition](https://coreos.github.io/ignition/examples/))

- 重新格式化/var文件系统
- 创建启用RAID的数据卷
- 将配置替换为远程配置
- 设置系统的主机名
- 添加用户
- 创建LUKS卷
- 设置内核参数

此配置将确保example和foo bar内核参数设置和somekarg内核参数未设置

```
{
  "ignition": {"version": "3.3.0"},
  "kernelArguments": {
    "shouldExist": ["example", "foo bar"],
    "shouldNotExist": ["somekarg"]
  }
}
```

#### 1.2 配置规范

Ignition配置必须符合特定版本的配置规范模式，并在配置中的**Ignition.version**字段指定，否则Ignition将无法运行并且机器不能启动。

建议使用最新的稳定版本的规范，Ignition目前支持的稳定的规范版本：v3.3.0、v3.2.0、v3.1.0、v3.0.0；

实验性规范版本：v3.4.0-experimental

每个稳定版本规范对应第一个支持它的Ignition发布版本，如下表：

| Spec Version | Ignition release |
| :----------- | ---------------- |
| 3.0.0        | 2.0.0            |
| 3.1.0        | 2.3.0            |
| 3.2.0        | 2.7.0            |
| 3.3.0        | 2.11.0           |

#### 1.3 升级配置

有时，对Ignition的配置所做的更改会破坏向后兼容性。由于Ignition在第一次启动时运行一次，所以对于正在运行的机器不会产生影响，但对维护配置文件增加了困难。[文档](https://coreos.github.io/ignition/migrating-configs/) 详细说明了从一个版本迁移到下一个版本时新增功能、弃用和更改的列表。其中，对于v3.0.0版本与以前的版本（v1及v2.x.0）完全不兼容。

#### 1.4 配置验证

Ignition-validate的cli工具的二进制文件，以及Ignition验证容器：quay.io/coreos/ignition-validate，可以用于验证Ignition的配置，验证示例：

	# This example uses podman， but docker can be used too
	podman run --pull=always --rm -i quay.io/coreos/ignition-validate:release - < myconfig.ign

#### 1.5 故障排除

##### 1.5.1 收集日志

故障排除时所需最有用的信息是Ignition的日志。Ignition在多个阶段运行，即可以通过syslog标识符进行过滤：ignition，命令如下：

	journalctl --identifier=ignition --all

注：如果没有任何结果，尝试以root身份运行。在某些情况下，日志不属于systemd-journal组，或者当前用户不属于该组。

##### 1.5.2 增加冗长

在机器无法启动的情况下，可以要求journald将更多信息记录到控制台。下面的内核参数将增加控制台的日志输出，使所有Ignition的日志可见：

	systemd.journald.max_level_console=debug

##### 1.5.3 验证配置

Ignition失败的一个常见原因是格式错误（如拼写错误或不正确的层次结构），这部分可以利用配置验证工具进行调试。

#### 1.6 启动systemd服务

当Ignition启动systemd服务时，它不会直接创建systemd所需的符号链接，而是利用了[systemd.preset](https://www.freedesktop.org/software/systemd/man/systemd.preset.html)。预设仅在第一次启动时评估，如果强制Ignition运行不止一次，这可能会导致混淆。在第一次启动后在配置中启用的任何systemd服务，在下次调用Ignition后将不会启用。systemctl preset-all需要手动调用以创建必要的符号链接，从而启用服务。

在机器的生命周期内，Ignition通常不会运行超过一次，因此这种需要手动systemd干预的情况通常不会出现。

#### 1.7 支持的平台

目前以下平台支持Ignition：

- 阿里云（aliyun）- Ignition将从实例用户数据中读取配置
- Amazon Web Services ( aws) - Ignition 将从实例用户数据中读取其配置
- Microsoft Azure ( azure)- Ignition 将从提供给实例的自定义数据中读取其配置

- Microsoft Azure Stack ( azurestack) - Ignition 将从提供给实例的自定义数据中读取其配置
- Brightbox ( brightbox) - Ignition 将从实例用户数据中读取其配置
- CloudStack ( cloudstack) - Ignition 将通过元数据服务或配置驱动器从实例用户数据读取其配置
- DigitalOcean ( digitalocean) - Ignition 将从Droplet 用户数据中读取其配置
- Exoscale ( exoscale) - Ignition 将从实例用户数据中读取其配置
- Google Cloud ( gcp) - Ignition 将从名为“user-data”的实例元数据条目中读取其配置
- IBM Cloud ( ibmcloud) - Ignition 将从实例用户数据中读取其配置
- KubeVirt (kubevirt) - Ignition将通过配置驱动器从实例用户数据读取配置
- Bare Metal ( metal) - 使用ignition.config.url内核参数提供配置的 URL。该URL可以使用http://，https://，tftp://，s3://，arn:，或gs://指定远程配置
- OpenStack ( openstack) - Ignition 将通过元数据服务或配置驱动器从实例用户数据读取其配置
- Equinix Metal ( packet) - Ignition 将从实例用户数据中读取其配置
- IBM Power Systems Virtual Server ( powervs) - Ignition 将从实例用户数据中读取其配置
- QEMU ( qemu) - Ignition 将从 QEMU 固件配置设备（在 QEMU 2.4.0 及更高版本中可用）上的“opt/com.coreos/config”键读取其配置。
- VirtualBox ( virtualbox) - 使用 VirtualBox 来宾属性/Ignition/Config为虚拟机提供配置
- VMware ( vmware) - 使用 VMware Guestinfo 变量ignition.config.data并向ignition.config.data.encoding虚拟机提供配置及其编码
- Vultr ( vultr) - Ignition 将从实例用户数据中读取其配置
- zVM ( zvm) - Ignition 将直接从读取器设备读取其配置

注：NestOS目前暂无计划适配公有云平台。

### 三、实现-How does Ignition work？

#### 3.1 initrd(Initial RAM DISK)启动流程

系统第一次进行引导安装，启动流程将以initrd.target为目标（如下图所示）。开始点火，通过离线（或者在线）获取Ignition配置信息，通过ignition-kargs.service和ignition-disks.service对内核及磁盘进行设置。当到达initrd-root-device.target目标时，表示根文件系统设备可用，但是还没有挂载。如果成功的将根文件系统挂载到/sysroot目录，那么sysroot.mount单元将被启动，然后进一步到达initrd-root-fs.target目标。Ignition-files.service开始工作并对Ignition config中的文件（例：对/etc目录的修改）进行设置。然后initrd-parse-etc.service将分析/sysroot/etc/下的文件，并挂载到/sysroot之下，然后流程到达initrd-fs.target目标。点火完成，initrd-cleanup.service将会使用systemctl --no-block isolate命令启动initrd-switch-root.target目标，最后启动initrd-switch-root.service服务，将系统的根目录切换至/sysroot目录。

![image-20220621093651418](/docs/graph/Ignition组件分析/image-20220621093651418.png)

```
###ignition-files.service 示例

[Unit]
Description=Ignition (files)
Documentation=https://coreos.github.io/ignition/
ConditionPathExists=/etc/initrd-release
DefaultDependencies=false
Before=ignition-complete.target

OnFailure=emergency.target
OnFailureJobMode=isolate

# Stage order: fetch-offline [-> fetch] [-> kargs] -> disks -> mount -> files.
After=ignition-mount.service

# Run before initrd-parse-etc so that we can drop files it then picks up.
Before=initrd-parse-etc.service

[Service]
Type=oneshot
RemainAfterExit=yes
EnvironmentFile=/run/ignition.env
ExecStart=/usr/bin/ignition --root=/sysroot --platform=${PLATFORM_ID} --stage=files --log-to-stdout
```

#### 3.2 Ignition创建unit文件流程

![image-20220621093808477](/docs/graph/Ignition组件分析/image-20220621093808477.png)

#### 3.3 Ignition主要代码框架

![image-20220621094213306](/docs/graph/Ignition组件分析/image-20220621094213306.png)

### 四、注意事项

#### 4.1 只读目录

- 由于OSTree用于管理属于操作系统的所有文件，因此 / 和 /usr 挂载点是不可写的。对操作系统的任何更改都应该通过rpm-ostree应用；
- 同样，/boot挂载点是不可写的，并且默认情况下EFI系统分区不挂载。这些文件系统由rpm-ostree和bootup管理，并且管理员不能直接修改它们；
- 目前不支持创建顶层目录（例如：/foo）；
- 根目录 / 以只读方式挂载在/sysroot中，不能直接访问或修改； 

#### 4.2 可变目录

仅支持写的目录是/etc和/var，/etc目录应该仅包含配置文件，并且不应该存储数据。所有数据必须保存在/var下，系统升级时不会改动。一般可能保存数据（例如/home或者/srv）的地方是链接到/var文件夹（例如/var/home或者/var/srv）

#### 4.3 内核参数

如果不计划Ignition实现提供kargs功能，则可以禁用该`ignition-kargs.service`















