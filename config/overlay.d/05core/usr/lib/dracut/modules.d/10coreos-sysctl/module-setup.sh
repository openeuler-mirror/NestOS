# For now we are using kmsg [1] for multiplexing output to
# multiple console devices during early boot. We need to also tell
# the kernel not to ratelimit kmsg during the initramfs.
#
# We do not want to use kmsg in the future as there may be sensitive
# ignition data that leaks to non-root users (by reading the kernel
# ring buffer using `dmesg`). In the future we will rely on kernel
# console multiplexing [2] for this and will not use kmsg.
#



check() {
    return 0
}

install() {
    mkdir -p "$initdir/etc/sysctl.d"
    echo "kernel.printk_devkmsg = on" > "$initdir/etc/sysctl.d/10-dont-ratelimit-kmsg.conf"
}
