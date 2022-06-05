#!/bin/sh

if [[ "${INSTALL_VERSION}" != "disable" ]]; then
    /workdir/install.sh
fi

if [[ "${UPDATE_GEODATA}" = "true" ]]; then
    /workdir/install_geodata.sh
fi

exec runsvdir -P /etc/service