#!/bin/bash
set -x

A=$(ps -C nginx --no-header | wc -l)
if [ $A -eq 0 ]; then

  echo $(date)':  nginx is not healthy, try to killall keepalived' >>/usr/local/etc/keepalived/keepalived.log
  killall keepalived
fi
