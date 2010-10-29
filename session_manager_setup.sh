#!/bin/sh

# Copyright (c) 2010 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Set up to start the X server ASAP, then let the startup run in the
# background while we set up other stuff.
XAUTH_FILE="/var/run/chromelogin.auth"
MCOOKIE=$(head -c 8 /dev/urandom | openssl md5)  # speed this up?
xauth -q -f ${XAUTH_FILE} add :0 . ${MCOOKIE}

# The X server sends SIGUSR1 to its parent once it's ready to accept
# connections.  The subshell here starts X, waits for the signal, then
# terminates once X is ready.
( trap 'exit 0' USR1 ; xstart.sh ${XAUTH_FILE} & wait ) &


export USER=chronos
export DATA_DIR=/home/${USER}
export LOGIN_PROFILE_DIR=${DATA_DIR}/Default
export LOGNAME=${USER}
export SHELL=/bin/sh
export HOME=${DATA_DIR}/user
export DISPLAY=:0.0
export GTK_IM_MODULE=ibus
# By default, libdbus treats all warnings as fatal errors. That's too strict.
export DBUS_FATAL_WARNINGS=0

# Tell Chrome where to write logging messages.
# $CHROME_LOG_DIR and $CHROME_LOG_PREFIX are defined in ui.conf,
# and the directory is created there as well.
export CHROME_LOG_FILE="${CHROME_LOG_DIR}/${CHROME_LOG_PREFIX}"

# Forces Chrome mini dumps that are sent to the crash server to also be written
# locally.  Chrome by default will create these mini dump files in
# ~/.config/google-chrome/Crash Reports/
if [ -f /mnt/stateful_partition/etc/enable_chromium_minidumps ] ; then
  export CHROME_HEADLESS=1
  # If possible we would like to have the crash reports located somewhere else
  if [ ! -f ~/.config/google-chrome/Crash\ Reports ] ; then
    mkdir -p /mnt/stateful_partition/var/minidumps/
    chown chronos /mnt/stateful_partition/var/minidumps/
    ln -s /mnt/stateful_partition/var/minidumps/ \
      ~/.config/google-chrome/Crash\ Reports
  fi
fi

export XAUTHORITY=${DATA_DIR}/.Xauthority

mkdir -p ${DATA_DIR} && chown ${USER}:${USER} ${DATA_DIR}
mkdir -p ${HOME} && chown ${USER}:${USER} ${HOME}
xauth -q -f ${XAUTHORITY} add :0 . ${MCOOKIE} &&
  chown ${USER}:${USER} ${XAUTHORITY}

# Old builds will have a ${LOGIN_PROFILE_DIR} that's owned by root; newer ones
# won't have this directory at all.
mkdir -p ${LOGIN_PROFILE_DIR}
chown ${USER}:${USER} ${LOGIN_PROFILE_DIR}

# temporary hack to tell cryptohome that we're doing chrome-login
touch /tmp/doing-chrome-login

# TODO: Remove auto_proxy environment variable when proxy settings
# are exposed in the UI.
if [ -f /home/chronos/var/default_proxy ] ; then
  export auto_proxy=$(cat /home/chronos/var/default_proxy)
else
  if [ -f /etc/default_proxy ] ; then
    export auto_proxy=$(cat /etc/default_proxy)
  fi
fi

CHROME="/opt/google/chrome/chrome"
# Note: If this script is renamed, ChildJob::kWindowManagerSuffix needs to be
# updated to contain the new name.  See http://crosbug.com/7901 for more info.
WM_SCRIPT="/sbin/window-manager-session.sh"
SEND_METRICS="/etc/send_metrics"
CONSENT_FILE="$DATA_DIR/Consent To Send Stats"

# xdg-open is used to open downloaded files.
# It runs sensible-browser, which uses $BROWSER.
export BROWSER=${CHROME}

USER_ID=$(id -u ${USER})

SKIP_OOBE=
# For test automation.  If file exists, do not remember last username and skip
# out-of-box-experience windows except the login window
if [ -f /root/.forget_usernames ] ; then
  rm -f "${DATA_DIR}/Local State"
  SKIP_OOBE="--login-screen=login"
fi

# For recovery image, do NOT display OOBE or login window
if [ -f /mnt/stateful_partition/.recovery ]; then
  # Verify recovery UI HTML file exists
  if [ -f /usr/share/misc/recovery_ui.html ]; then
    SKIP_OOBE="--login-screen=html file:///usr/share/misc/recovery_ui.html"
  else
    # Fall back to displaying a blank screen
    # the magic string "test:nowindow" comes from
    # src/chrome/browser/chromeos/login/wizard_controller.cc
    SKIP_OOBE="--login-screen=test:nowindow"
  fi
fi

# Enables gathering of chrome dumps.  In stateful partition so testers
# can enable getting core dumps after build time.
if [ -f /mnt/stateful_partition/etc/enable_chromium_coredumps ] ; then
  mkdir -p /mnt/stateful_partition/var/coredumps/
  # Chrome runs and chronos so we need to change the permissions of this folder
  # so it can write there when it crashes
  chown chronos /mnt/stateful_partition/var/coredumps/
  ulimit -c unlimited
  echo "/mnt/stateful_partition/var/coredumps/core.%e.%p" > \
    /proc/sys/kernel/core_pattern
fi

if [ -f "$SEND_METRICS" ]; then
  if [ ! -f "$CONSENT_FILE" ]; then
    # Automatically opt-in to Chrome OS stats collecting.  This does
    # not have to be a cryptographically random string, but we do need
    # a 32 byte, printable string.
    head -c 8 /dev/random | openssl md5 > "$CONSENT_FILE"
  fi
fi

# We need to delete these files as Chrome may have left them around from
# its prior run (if it crashed).
rm -f ${DATA_DIR}/SingletonLock
rm -f ${DATA_DIR}/SingletonSocket

# Set up bios information for chrome://system and userfeedback
# Need to do this before user can request in chrome
# moved here to keep out of critical boot path

# Function for showing switch info (CHSW in Firmware High-Level Spec)
swstate () {
  if [ $(($1 & $2)) -ne 0 ]; then
    echo "$3 $4"; else echo "$3 $5"
  fi
}

# Function for showing boot reason (BINF in Firmware High-Level Spec)
bootreason () {
  echo -n "Boot reason ($1): "
  case $1 in
  1) echo "Normal";;
  2) echo "Developer mode";;
  3) echo "Recovery, button pressed";;
  4) echo "Recovery, from developer mode";;
  5) echo "Recovery, no valid RW firmware";;
  6) echo "Recovery, no OS";;
  7) echo "Recovery, bad kernel signature";;
  8) echo "Recovery, requested by OS";;
  9) echo "OS-initiated s3 debug mode";;
  10) echo "S3 resume failed";;
  11) echo "Recovery, TPM error";;
  esac
}

if [ -x /usr/sbin/mosys ]; then
  mosys -l smbios info bios > /var/log/bios_info.txt
else
  # message not blank on systems without mosys (ARM mosys is not done)
  echo "Unable to get bios information" > /var/log/bios_info.txt
fi
if [ -f /sys/devices/platform/chromeos_acpi/CHSW ]; then
  chsw=`cat /sys/devices/platform/chromeos_acpi/CHSW`
  echo "Boot switch status:"
  swstate $chsw 2 "  Recovery button" pressed released
  swstate $chsw 32 "  Developer mode:" selected "not enabled"
  swstate $chsw 512 "  RO firmware:" writeable protected
  bootreason `cat /sys/devices/platform/chromeos_acpi/BINF.0`
  echo "Boot firmware " `cat /sys/devices/platform/chromeos_acpi/BINF.1`
  echo "Active EC code: " `cat /sys/devices/platform/chromeos_acpi/BINF.2`
else
  echo "Non-Chrome OS firmware: no chromeos_acpi switch device was found"
fi >> /var/log/bios_info.txt


# The subshell that started the X server will terminate once X is
# ready.  Wait here for that event before continuing.
wait

# TODO: consider moving this when we start X in a different way.
initctl emit x-started
bootstat x-started

# When X starts, it copies the contents of the framebuffer to the root
# window.  We clear the framebuffer here to make sure that it doesn't flash
# back onscreen when X exits later.
/usr/bin/ply-image --clear &

#
# Reset PATH to exclude directories unneeded by session_manager.
# Save that until here, because many of the commands above depend
# on the default PATH handed to us by init.
#
export PATH=/bin:/usr/bin:/usr/bin/X11

# Set an environment variable to prevent Flash asserts from crashing the plugin
# process.
export DONT_CRASH_ON_ASSERT=1
PEPPER_FLASH_PLUGIN=/opt/google/chrome/pepper/libpepflashplayer.so
if [ -f $PEPPER_FLASH_PLUGIN ]; then
    PEPPER_FLASH_FLAG="--register-pepper-plugins=${PEPPER_FLASH_PLUGIN}#Shockwave Flash#Shockwave Flash 10.1 r53;application/x-shockwave-flash"
fi

exec /sbin/session_manager --uid=${USER_ID} -- \
    $CHROME --login-manager \
            --enable-gview \
            --log-level=0 \
            --enable-logging \
            --disable-seccomp-sandbox \
            --no-first-run \
            --user-data-dir="$DATA_DIR" \
            --login-profile=user \
            --in-chrome-auth \
            --apps-gallery-title="Web Store" \
            --apps-gallery-url="https://chrome.google.com/webstore/" \
            --enable-login-images \
            --enable-tabbed-options \
            --disable-domui-menu \
            --scroll-pixels=4 \
            "$PEPPER_FLASH_FLAG" \
            ${SKIP_OOBE} \
-- "$WM_SCRIPT"
