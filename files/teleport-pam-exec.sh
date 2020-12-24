#!/bin/sh
COMMENT="User ${TELEPORT_USERNAME} with roles ${TELEPORT_ROLES} created by Teleport."
id -u "${TELEPORT_LOGIN}" > /dev/null 2>&1 || /usr/sbin/useradd -m -g teleport-admin -c "${COMMENT}" "${TELEPORT_LOGIN}" > /dev/null 2>&1
exit 0
