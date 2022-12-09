# How to use rpm-ostree

## rpm-ostree installs the package

Installing wget

```
rpm-ostree install wget
```

![image-20211014201905155](/docs/zh/graph/rpm-ostree使用/image-20211014201905155.png)

To restart the system, press the key up or down on the keyboard to select the system status after the rpm package is installed or before the installation.The version after the installation is ostree:0.

```
systemctl reboot
```

![image-20211014201914711](/docs/zh/graph/rpm-ostree使用/image-20211014201914711.png)

Check whether wget is installed successfully

```
rpm -qa | grep wget
```

![image-20211014201922069](/docs/zh/graph/rpm-ostree使用/image-20211014201922069.png)

## rpm-ostree manually updates NestOS

Run the command in NestOS to view the status of rpm-ostree. You can see that the current version is LTS.20210927.dev.0.

```
rpm-ostree status
```

![image-20211014201929746](/docs/zh/graph/rpm-ostree使用/image-20211014201929746.png)

Run the check command to check whether the upgrade is available. The LTS.20210928.dev.0 version exists

```
rpm-ostree upgrade --check
```

![image-20211014201940141](/docs/zh/graph/rpm-ostree使用/image-20211014201940141.png)

Preview the differences in the version

```
rpm-ostree upgrade --preview
```

![image-20211014201948988](/docs/zh/graph/rpm-ostree使用/image-20211014201948988.png)

As you can see, in the latest version of 0928, we have introduced the wget package.
Download the latest ostree and RPM data without deployment

```
rpm-ostree upgrade --download-only
```

![image-20211014201956536](/docs/zh/graph/rpm-ostree使用/image-20211014201956536.png)

Restart NestOS. After the restart, you can view the status of the new and old versions of the system. Select the branch of the latest version

```
rpm-ostree upgrade --reboot
```

## Compare the NestOS version differences

Check the status and confirm that there are two versions of ostree at this time: LTS.20210927.dev.0 and LTS.20210928.dev.0

```
rpm-ostree status
```

![image-20211014202004110](/docs/zh/graph/rpm-ostree使用/image-20211014202004110.png)

Compare the difference between the two OSTrees according to the commit number

```
rpm-ostree db diff 55eed9bfc5ec fe2408e34148
```

![image-20211014202014370](/docs/zh/graph/rpm-ostree使用/image-20211014202014370.png)

## System Rollback

When a system update is complete, the previous NestOS deployment is still on disk, and if the update causes problems, the previous deployment can be used to roll back the system.

### Temporary rollback

To temporarily roll back to a previous OS deployment, hold down the shift key during system startup, and when the boot load menu appears, select the relevant branch in the menu.

### Permanent rollback

To permanently rollback to your previous operating system deployment, log in to the target node and run rpm-ostree rollback.This will use the previous system deployment as the default deployment and reboot to it.
Run the following command to roll back the system before the update.

```
rpm-ostree rollback
```

![image-20211014202023177](/docs/zh/graph/rpm-ostree使用/image-20211014202023177.png)

The system becomes invalid after restart.

## Switching versions

In the previous step, NestOS is rolled back to LTS.20210927.dev.0. You can run the command to switch rpm-ostree version used by NestOS to switch LTS.20210927.dev.0 to LTS.20210928.dev.0.

```
rpm-ostree deploy -r LTS.20210928.dev.0
```

![image-20211014202030442](/docs/zh/graph/rpm-ostree使用/image-20211014202030442.png)

After the restart, confirm that the current NestOS has used the LTS.20210928.dev.0 version of ostree.

![image-20211014202037703](/docs/zh/graph/rpm-ostree使用/image-20211014202037703.png)

