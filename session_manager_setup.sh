#!/bin/sh

# Copyright (c) 2010 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

XAUTH=/usr/bin/xauth
XAUTH_FILE="/var/run/chromelogin.auth"
SERVER_READY=

user1_handler () {
  echo "received SIGUSR1!"
  SERVER_READY=y
}

trap user1_handler USR1
MCOOKIE=$(head -c 8 /dev/urandom | openssl md5)  # speed this up?
${XAUTH} -q -f ${XAUTH_FILE} add :0 . ${MCOOKIE}

/sbin/xstart.sh ${XAUTH_FILE} &

while [ -z ${SERVER_READY} ]; do
  sleep .1
done

export USER=chronos
export DATA_DIR=/home/${USER}
export LOGNAME=${USER}
export SHELL=/bin/bash
export HOME=${DATA_DIR}/user
export DISPLAY=:0.0
export PATH=/bin:/usr/bin:/usr/local/bin:/usr/bin/X11
export GTK_IM_MODULE=ibus

XAUTH_FILE=${DATA_DIR}/.Xauthority
export XAUTHORITY=${XAUTH_FILE}

mkdir -p ${DATA_DIR} && chown ${USER}:${USER} ${DATA_DIR}
mkdir -p ${HOME} && chown ${USER}:${USER} ${HOME}
${XAUTH} -q -f ${XAUTH_FILE} add :0 . ${MCOOKIE} && \
  chown ${USER}:${USER} ${XAUTH_FILE}

# temporary hack to tell cryptohome that we're doing chrome-login
touch /tmp/doing-chrome-login

CHROME_DIR="/opt/google/chrome"
CHROME="$CHROME_DIR/chrome"
COOKIE_PIPE="/tmp/cookie_pipe"
MANAGER_PIPE="/tmp/session_manager_pipe"

# xdg-open is used to open downloaded files.
# It runs sensible-browser, which uses $BROWSER.
export BROWSER=${CHROME}

USER_ID=$(/usr/bin/id -u ${USER})
exec /sbin/session_manager --uid=${USER_ID} --login --pipe=${MANAGER_PIPE} -- \
    /usr/bin/ck-launch-session \
    $CHROME --enable-gview \
	    --enable-sync \
	    --main-menu-url="http://welcome-cros.appspot.com/menu" \
            --no-first-run \
            --user-data-dir=/home/$USER \
            --profile=user \
            "--cookie-pipe=$COOKIE_PIPE"
