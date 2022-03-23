#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh


install_unit() {
    local unit=$1; shift
    inst_simple "$moddir/$unit" "$systemdsystemunitdir/$unit"
    # note we `|| exit 1` here so we error out if e.g. the units are missing
    systemctl -q --root="$initdir" add-requires initrd.target "$unit" || exit 1
}

install() {
    inst_multiple \
        touch

    # TODO f35: check if we can drop this whole module
    install_unit coreos-touch-run-agetty.service
}