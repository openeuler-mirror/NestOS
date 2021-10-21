#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# We want to provide Azure udev rules as part of the initrd, so that Ignition
# is able to detect disks and act on them.
#
# If the WALinuxAgent-udev package is changed to install the udev rules as
# part of the initramfs, we should drop this module.
#


install() {
    inst_multiple \
        /usr/lib/udev/rules.d/66-azure-storage.rules \
        /usr/lib/udev/rules.d/99-azure-product-uuid.rules
}
