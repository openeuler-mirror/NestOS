# 定制NestOS

我们可以使用nestos-installer 工具对原始的NestOS ISO文件进行加工，将Ignition文件打包进去从而生成定制的 NestOS ISO文件。使用定制的NestOS ISO文件可以在系统启动完成后自动执行NestOS的安装，因此NestOS的安装会更加简单。

在开始定制NestOS之前，需要做如下准备工作：

- 下载 NestOS ISO
- 准备 config.ign文件

## 生成定制NestOS ISO文件

### 设置参数变量

```
$ export COREOS_ISO_ORIGIN_FILE=nestos-LTS.20211009.dev.0-live.x86_64.iso
$ export COREOS_ISO_CUSTOMIZED_FILE=my-nestos.iso
$ export IGN_FILE=config.ign
```

### ISO文件检查

确认原始的NestOS ISO文件中是没有包含Ignition配置。

```
$ nestos-installer iso ignition show $COREOS_ISO_ORIGIN_FILE 

Error: No embedded Ignition config.
```

### 生成定制NestOS ISO文件

将Ignition文件和原始NestOS ISO文件打包生成定制的NestOS ISO文件。

```
$ nestos-installer iso ignition embed $COREOS_ISO_ORIGIN_FILE --ignition-file $IGN_FILE $COREOS_ISO_ORIGIN_FILE --output $COREOS_ISO_CUSTOMIZED_FILE
```

### ISO文件检查

确认定制NestOS ISO 文件中已经包含Ignition配置了

```
$ nestos-installer iso ignition show $COREOS_ISO_CUSTOMIZED_FILE
```

执行命令，将会显示Ignition配置内容

## 安装定制NestOS ISO文件

使用定制的 NestOS ISO 文件可以直接引导安装，并根据Ignition自动完成NestOS的安装。在完成安装后，我们可以直接在虚拟机的控制台上用core/password登录NestOS。