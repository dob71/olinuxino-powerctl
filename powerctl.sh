#!/bin/bash

mkdir -p /ups/relays
for r in 1 2 3 4; do
  [ -f "/ups/relays/$r" ] || echo "on" > "/ups/relays/$r"
done

UPDATE_FILE="/ups/relays/updated"
touch "$UPDATE_FILE"

mkdir -p /var/run
echo "$$" > /var/run/powerctl.pid

while true; do
  if [ -e "$UPDATE_FILE" ]; then
    rm -f "$UPDATE_FILE"
    MASK=0
    ERR=0
    for r in 1 2 3 4; do
      state=$(cat /ups/relays/$r)
      if [ "$state" == "off" ]; then
        let "MASK = $MASK | (1 << ($r - 1))"
        logger -t POWERCTL "Relay $r - On"
      elif [ "$state" == "on" ]; then
        let "MASK = $MASK & ~(1 << ($r - 1))"
        logger -t POWERCTL "Relay $r - Off"
      else
        ERR=1
        logger -t POWERCTL "Error: bad state '$state' for relay $r"
      fi
    done
    if [ $ERR -eq 0 ]; then
       i2cset -y -f 2 0x58 0x10 $(printf "0x%x" $MASK)
    else
       touch "$UPDATE_FILE"
    fi
  fi
  sleep 1
done

