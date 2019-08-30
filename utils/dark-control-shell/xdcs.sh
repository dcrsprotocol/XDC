#!/bin/sh

# Copyright (c) 2016-2018, Dark developers 
#
# All rights reserved
#
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this list of
#    conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, this list
#    of conditions and the following disclaimer in the documentation and/or other
#    materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors may be
#    used to endorse or promote products derived from this software without specific
#    prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
# THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


DATA_DIR="/var/dark"
LOG_DIR="/var/log/dark"
RUN_DIR="/var/run/dark"

XDCS="/usr/sbin/simplewallet"

XDCS_NODE_HOST="127.0.0.1"
XDCS_NODE_PORT="26151"
XDCS_WALLET="Wallet.dat"
XDCS_PASS="pass"
XDCS_LOG_LEVEL="3"
XDCS_RPC_IP="127.0.0.1"
XDCS_RPC_PORT="15000"

SIGTERM_TIMEOUT=30
SIGKILL_TIMEOUT=20

XDCS_WALLET=$DATA_DIR/$XDCS_WALLET


## Base check

# Check all work directories
if [ -d $DATA_DIR ]; then
  if [ ! -w $DATA_DIR ]; then
    echo "Error: DATA dir not writable!"
    exit 1
  fi
else
  echo "Error: DATA dir not found!"
  exit 1
fi

if [ -d $LOG_DIR ]; then
  if [ ! -w $LOG_DIR ]; then
    echo "Error: LOG dir not writable!"
    exit 1
  fi
else
  echo "Error: LOG dir not found!"
  exit 1
fi

if [ -d $RUN_DIR ]; then
  if [ ! -w $RUN_DIR ]; then
    echo "Error: RUN dir not writable!"
    exit 1
  fi
else
  echo "Error: RUN dir not found!"
  exit 1
fi

# Check all bin files
if [ ! -f $XDCS ]; then
  echo "Error: SIMPLEWALLET bin file not found!"
  exit 1
fi

if [ ! -f $XDCS_WALLET.wallet ]; then
  echo "Error: wallet bin file not found!"
  exit 1
fi


# Function logger
logger(){
  if [ ! -f $LOG_DIR/xdcs_control.log ]; then
    touch $LOG_DIR/xdcs_control.log
  fi
  mess=[$(date '+%Y-%m-%d %H:%M:%S')]" "$1
  echo $mess >> $LOG_DIR/xdcs_control.log
  echo $mess
}

# Funstion locker
locker(){
  if [ "$1" = "check" ]; then
    if [ -f $RUN_DIR/xdcs_control.lock ]; then
      logger "LOCKER: previous task is not completed; exiting..."
      exit 0
    fi
  fi
  if [ "$1" = "init" ]; then
    touch $RUN_DIR/xdcs_control.lock
  fi
    if [ "$1" = "end" ]; then
    rm -f $RUN_DIR/xdcs_control.lock
  fi
}

# Function init service
service_init(){
  $XDCS --wallet-file $XDCS_WALLET \
        --password $XDCS_PASS \
        --daemon-host $XDCS_NODE_HOST \
        --daemon-port $XDCS_NODE_PORT \
        --rpc-bind-ip $XDCS_RPC_IP \
        --rpc-bind-port $XDCS_RPC_PORT \
        --log-file $LOG_DIR/xdcs.log \
        --log-level $XDCS_LOG_LEVEL > /dev/null & echo $! > $RUN_DIR/XDCS.pid
}

# Function start service
service_start(){
  if [ ! -f $RUN_DIR/XDCS.pid ]; then
    logger "START: trying to start service..."
    service_init
    sleep 5
    if [ -f $RUN_DIR/XDCS.pid ]; then
      pid=$(sed 's/[^0-9]*//g' $RUN_DIR/XDCS.pid)
      if [ -f /proc/$pid/stat ]; then
        logger "START: success!"
      fi
    fi
  else
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/XDCS.pid)
    if [ -f /proc/$pid/stat ]; then
      logger "START: process is already running"
    else
      logger "START: abnormal termination detected; starting..."
      rm -f $RUN_DIR/XDCS.pid
      service_init
      sleep 5
      if [ -f $RUN_DIR/XDCS.pid ]; then
        pid=$(sed 's/[^0-9]*//g' $RUN_DIR/XDCS.pid)
        if [ -f /proc/$pid/stat ]; then
          logger "START: success!"
        fi
      fi
    fi
  fi
}

# Function stop service
service_stop(){
  if [ -f $RUN_DIR/XDCS.pid ]; then
    logger "STOP: attempting to stop the service..."
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/XDCS.pid)
    if [ -f /proc/$pid/stat ]; then
      kill $pid
      sleep 5
      for i in $(seq 1 $SIGTERM_TIMEOUT); do
        if [ ! -f /proc/$pid/stat ]; then
          rm -f $RUN_DIR/XDCS.pid
          logger "STOP: success!"
          break
        fi
        sleep 1
      done
      if [ -f $RUN_DIR/XDCS.pid ]; then
        logger "STOP: attempt failed, trying again..."
        kill -9 $pid
        sleep 5
        for i in $(seq 1 $SIGKILL_TIMEOUT); do
          if [ ! -f /proc/$pid/stat ]; then
            rm -f $RUN_DIR/XDCS.pid
            logger "STOP: service has been killed (SIGKILL) due to ERROR!"
            break
          fi
          sleep 1
        done
      fi
    else
      logger "STOP: PID file found, but service not detected; possible error..."
      rm -f $RUN_DIR/XDCS.pid
    fi
  else
    logger "STOP: no service found!"
  fi
}


do_start(){
  logger "DO START: procedure initializing..."
  service_start
  logger "DO START: ok"
}

do_stop(){
  logger "DO STOP: procedure initializing..."
  service_stop
  logger "DO STOP: ok"
}

do_restart(){
  logger "DO RESTART: procedure initializing..."
  service_stop
  service_start
  logger "DO RESTART: ok"
}


# Command selector
locker "check"
locker "init"

case "$1" in
  "--start")
  do_start
  ;;
  "--stop")
  do_stop
  ;;
  "--restart")
  do_restart
  ;;
  *)
  logger "SELECTOR: unknown command"
  ;;
esac

locker "end"