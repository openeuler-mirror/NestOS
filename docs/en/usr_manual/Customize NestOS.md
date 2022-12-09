# Customize NestOS

You can modify the original NestOS ISO using the Nestos-Installer tool, and package the ignition file to generate a custom NestOS ISO, which makes it easier to install NestOS automatically after the system is booted.

Before:

- Download NestOS ISO
- Prepare config.ign

## Generate the custom NestOS ISO

### Set parameters

```
$ export COREOS_ISO_ORIGIN_FILE=nestos-LTS.20211009.dev.0-live.x86_64.iso
$ export COREOS_ISO_CUSTOMIZED_FILE=my-nestos.iso
$ export IGN_FILE=config.ign
```

### Check ISO

Confirm that the original NestOS ISO did not contain the ignition configuration.

```
$ nestos-installer iso ignition show $COREOS_ISO_ORIGIN_FILE 

Error: No embedded Ignition config.
```

### Generate the custom NestOS ISO

Package the ignition file with the original NestOS ISO to generate the custom NestOS ISO.

```
$ nestos-installer iso ignition embed $COREOS_ISO_ORIGIN_FILE --ignition-file $IGN_FILE $COREOS_ISO_ORIGIN_FILE --output $COREOS_ISO_CUSTOMIZED_FILE
```

### Check ISO

Verify that your custom NestOS ISO already contains the ignition configuration.

```
$ nestos-installer iso ignition show $COREOS_ISO_CUSTOMIZED_FILE
```

With the command, the ignition configuration will be displayed.

## Install

Using the custom NestOS ISO, you can boot the installation directly and automatically complete the NestOS installation according to Ignition. After the installation is complete, you can log in to NestOS directly from the virtual machine console with core/password.