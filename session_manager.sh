#!/bin/sh

# Copyright (c) 2009 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

XAUTH_FILE="/var/run/chromelogin.auth"
SERVER_READY=

user1_handler () {
  echo "received SIGUSR1!"
  SERVER_READY=y
}

trap user1_handler USR1
MCOOKIE=$(head -c 8 /dev/urandom | openssl md5)  # speed this up?
/usr/bin/xauth -q -f ${XAUTH_FILE} add :0 . ${MCOOKIE}

/etc/init.d/xstart.sh ${XAUTH_FILE} &

while [ -z ${SERVER_READY} ]; do
  sleep .1
done

export USER=chronos
export DATA_DIR=/home/${USER}
mkdir -p ${DATA_DIR} && chown ${USER}:admin ${DATA_DIR}
exec su ${USER} -c "/usr/bin/ck-launch-session /etc/init.d/start_login.sh ${MCOOKIE}"

