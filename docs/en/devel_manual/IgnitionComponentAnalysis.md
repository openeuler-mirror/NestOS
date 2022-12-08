# Ignition Component Analysis



Ignition version：v2.14

github address：https://github.com/coreos/ignition.git

NestOS integrates the configuration tool Ignition. When you deploy and configure a NestOS system, you need to prepare a custom ignition configuration file, which is configured through the Ignition component during the first boot phase of the system. Nestos is intended to be managed as an immutable infrastructure, meaning that machines should not be reconfigured once they have been deployed and initially configured. If you need to change the configuration, you need to redeploy with the new ignition configuration file. Using the same ignition configuration file makes it easy to scale machines on a large cluster deployment. Here's a quick overview of the Ignition component's characteristics and code structure.

### 一、overview-what is Ignition

Ignition is a configuration utility that reads a JSON-format configuration file whose components include creating users, adding trusted SSH keys, starting systemd services, and more.

Ignition only runs when the system first starts up (during initramfs), and because Ignition runs in the early stages of the boot process, you can repartition disks, format the file system, create users, and write files before user space starts to boot. And the systemd service writes to the disk before systemd starts, speeding up boot time. When Ignition runs, it looks up configuration data, such as a file or URL, in a named location in a given environment and applies it to the machine to go to the machine's root file system before the switch_root call.

#### 1.1 Configuration Process

To make it easier for users to read and write, Ignition documents have added a step to the conversion process

1）Write a Butane config（yaml format）

2）Convert Butane config to Ignition config (json format)

3）Boot the new NestOS image using the generated Ignition config

```
# Butane configuration is converted to the Ignition configuration
podman run --interactive --rm quay.io/coreos/butane:release --pretty --strict < your_config.bu > transpiled_config.ign
```

### 二、Ability-What can Ignition do？

#### 1.1 Configuration Example

- Starting the Service

Sample Ignition Configuration：

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

- Modify the service

This configuration adds a systemd unit plug-in that modifies the existing service systemd-journald.service and sets its environment variable SYSTEMD_LOG_LEVEL to debug

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

- Create a file on the root file system

This example writes a single file to the /etc/someconfig root file system

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

Ignition can also be configured for the following scenarios, which you can see for details [Configuration Example]([Example Configs - coreos/ignition](https://coreos.github.io/ignition/examples/))

- Reformats the /var file system
- Create RAID enabled data volumes
- Replace configuration with remote configuration
- Set the system host name
- Add a user
- Create a LUKS volume
- Set kernel parameters

This configuration ensures that the example and foo bar kernel parameters are set and the somekarg kernel parameters are not set

```
{
  "ignition": {"version": "3.3.0"},
  "kernelArguments": {
    "shouldExist": ["example", "foo bar"],
    "shouldNotExist": ["somekarg"]
  }
}
```

#### 1.2 Configuration Specifications

The Ignition configuration must conform to the configuration specification pattern for a particular version and be specified in the **Ignition.version** field in the configuration, otherwise Ignition will not run and the machine will not start.

It is recommended to use the latest stable version of the specification. The stable version of the specification currently supported by Ignition is v3.3.0, v3.2.0, v3.1.0, v3.0.0;

experimental specification version: v3.4.0-experimental

Each stable release specification corresponds to the first Ignition release that supports it, as shown in the table below:

| Spec Version | Ignition release |
| :----------- | ---------------- |
| 3.0.0        | 2.0.0            |
| 3.1.0        | 2.3.0            |
| 3.2.0        | 2.7.0            |
| 3.3.0        | 2.11.0           |

#### 1.3 Upgrade Configuration

Sometimes, changes made to Ignition's configuration break backward compatibility. Because Ignition runs once on the first start up, it has no impact on the running machine, but it makes it harder to maintain configuration files. [documents](https://www.freedesktop.org/software/systemd/man/systemd.preset.html) detailing the migration from one version to the next version of the new features, abandoned, and the list of changes. The v3.0.0 version is completely incompatible with previous versions (v1 and v2.x.0).

#### 1.4 Configuration Verification

 quay.io/coreos/ ignition-validate-This can be used to verify the Ignition configuration, for example:

	# This example uses podman， but docker can be used too
	podman run --pull=always --rm -i quay.io/coreos/ignition-validate:release - < myconfig.ign

#### 1.5 Troubleshooting

##### 1.5.1 Collecting Logs

The most useful information you need for troubleshooting is the Ignition log. Ignition runs in multiple stages, which means it can be filtered through the syslog identifier: ignition, with the following command:

	journalctl --identifier=ignition --all

Note: If nothing results, try running as root. In some cases, logs do not belong to the systemd-journal group, or the current user does not belong to the group.

##### 1.5.2 Add verbosity

In case the machine fails to start, journald can be asked to log more information to the console. The following kernel parameters increase the console's log output, making all Ignition logs visible:

	systemd.journald.max_level_console=debug

##### 1.5.3 Verifying the Configuration

A common reason for Ignition failure is formatting errors (such as misspellings or incorrect hierarchies), which you can debug with configuration validation tools.

#### 1.6 Start the systemd service

When Ignition starts the systemd service, it does not directly create the symlinks required by systemd, But the use of [systemd preset](https://www.freedesktop.org/software/systemd/man/systemd.preset.html). The default is evaluated only on the first startup, which can lead to confusion if you force Ignition to run more than once. Any systemd services that are enabled in the configuration after the first startup will not be enabled the next time Ignition is called. systemctl preset-all requires a manual call to create the necessary symbolic links to enable the service.

Ignition typically does not run more than once in a machine's lifetime, so situations like this that require manual systemd intervention do not usually arise.

#### 1.7 Supported Platforms

The following platforms currently support Ignition:

- aliyun
- Amazon Web Services ( aws)
- Microsoft Azure ( azure)

- Microsoft Azure Stack ( azurestack) 
- Brightbox ( brightbox)
- CloudStack ( cloudstack) 
- DigitalOcean ( digitalocean) 
- Exoscale ( exoscale) 
- Google Cloud ( gcp) 
- IBM Cloud ( ibmcloud) 
- KubeVirt (kubevirt) 
- Bare Metal ( metal) 
- OpenStack ( openstack) 
- Equinix Metal ( packet) 
- IBM Power Systems Virtual Server ( powervs)
- QEMU ( qemu) 
- VirtualBox ( virtualbox) 
- VMware ( vmware)
- Vultr ( vultr) 
- zVM ( zvm) 

Note: NestOS has no plan to be adapted to public cloud platforms at present.

### 三、Implementation-How does Ignition work？

#### 3.1 initrd(Initial RAM DISK)

For the first boot installation, the boot process will target initrd.target (as shown below). Start the ignition, get the ignition configuration information offline (or online), and set the kernel and disk via ignite-kargs.service and ignite-Disks.service. When the target of initrd-root-device.target is reached, the root file system device is available but not mounted. If the root file system is successfully mounted to the /sysroot directory, the sysroot.mount unit is started and then further to the initrd-root-fs.target target. Ignition-files.service starts working and sets up the files in Ignition config (for example, changes to the /etc directory). initrd-parse-etc.service then analyzes the files under /sysroot/etc/ and mounts them under /sysroot, and the process reaches the initrd-fs.target target. When the ignition is complete, initrd-cleanup.service will start the initrd-switch-root.target with the systemctl --no-block isolate command. Finally, start the initrd-switch-root.service service to switch the root directory of the system to /sysroot.

![image-20220621093651418](/docs/en/graph/IgnitionComponentAnalysis/image-20220621093651418.jpg)

```
###ignition-files.service

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

#### 3.2 Ignition creates the unit file process

![](/docs/en/graph/IgnitionComponentAnalysis/image-20220621093808477.jpg)

#### 3.3 Ignition code framework

![image-20220621094213306](/docs/en/graph/IgnitionComponentAnalysis/image-20220621094213306.jpg)

### 四、Focus on

#### 4.1 Read only directory

- Since OSTree is used to manage all files belonging to the operating system, the / and /usr mount points are not writable. Any changes to the operating system should be applied through rpm-ostree;
- Again, the /boot mount point is not writable, and EFI system partitions are not mounted by default. These file systems are managed by rpm-ostree and bootup, and cannot be modified directly by the administrator;
- Currently, creating a top-level directory (for example, /foo) is not supported.
- The root directory / is mounted in /sysroot in read-only mode and cannot be accessed or modified directly;

#### 4.2 Variable directory

The only directories that can be written are /etc/var. The /etc directory should contain only configuration files and should not store data. All data must be saved under /var and will not be changed during system upgrade. A common place to save data (such as /home or /srv) is to link it to the /var folder (such as /var/home or /var/srv).

#### 4.3 Kernel parameters

If you do not plan to have your Ignition implementation provide kargs functionality, you can disable 'ignition- Kargs.service'















