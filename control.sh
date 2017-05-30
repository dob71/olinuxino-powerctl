#!/bin/bash

PATH=$PATH:/sbin:/usr/sbin

MYUSER="admin"
MODE="_main"
mkdir -p /ups/relays
for r in 1 2 3 4; do
  [ -f "/ups/relays/$r" ] || echo "on" > "/ups/relays/$r"
done
[ -f /ups/wifi/ssid ] || echo "realsmartups" > /ups/wifi/ssid
[ -f /ups/wifi/pass ] || echo "power123" > /ups/wifi/pass

touch "/ups/relays/updated"

echo "Please press a key:"

function _power() {
  echo "Current power state:"
  echo "R1(surge outlet 1) : $(cat /ups/relays/1)"
  echo "R2(surge outlet 2) : $(cat /ups/relays/2)"
  echo "R3(surge outlet 3) : $(cat /ups/relays/3)"
  echo "R4(battery outlets): $(cat /ups/relays/4)"
  echo "1-4 toggle the state, 'u' - all on, 'd' - all off, 'e' - exit:"
  read -rsn1 in
  if [ "$in" = "1" ] || [ "$in" = "2" ] || [ "$in" = "3" ] || [ "$in" = "4" ]
  then
    STATE=`cat /ups/relays/$in`
    if [ "$STATE" = "on" ]; then
      STATE="off"
    else
      STATE="on"
    fi
    echo "$STATE" > "/ups/relays/$in"
    touch "/ups/relays/updated"
  elif [ "$in" = "u" ] || [ "$in" = "U" ]; then
    for r in 1 2 3 4; do
      echo "on" > "/ups/relays/$r"
    done
    touch "/ups/relays/updated"
  elif [ "$in" = "d" ] || [ "$in" = "D" ]; then
    for r in 1 2 3 4; do
      echo "off" > "/ups/relays/$r"
    done
    touch "/ups/relays/updated"
  elif [ "$in" = "e" ] || [ "$in" = "E" ]; then
    MODE="_main"
  else
    echo "Unrecognized input!"
  fi
}

function _ssid_pass() {
  SSID=$(cat /ups/wifi/ssid)
  PASS=$(cat /ups/wifi/pass)
  read -e -n 32 newssid
  if [ "$newssid" != "" ]; then
    echo "$newssid" > /ups/wifi/ssid
    SSID=$(cat /ups/wifi/ssid)
  fi
  echo "Using SSID: \"$SSID\""
  while true; do
    echo "WPA-PSK password ($PASS):"
    read -e -n 64 newpass
    if [ ${#newpass} -ne 0 ] && [ ${#newpass} -lt 8 ]; then
      echo "Password too short, must be 8 or more characters."
      continue
    fi
    if [ "$newpass" != "" ]; then
      echo "$newpass" > /ups/wifi/pass
      PASS=$(cat /ups/wifi/pass)
    fi
    break
  done
  echo "Using password: \"$PASS\""
}

function _wifi() {
  DNSCFG="/etc/dnsmasq.conf"
  HOSTAPDCFG="/etc/hostapd/hostapd.conf"
  WLAN=`ls -1 /sys/class/net/ | grep wlan`
  if [ -f "$HOSTAPDCFG" ]; then
    echo "The system is in AP mode"
  else
    echo "The system is in STA mode"
  fi
  if [ "$WLAN" == "" ]; then
    echo "No wireless device, assuming wlan0!"
    WLAN="wlan0"
  else
    echo "Wireless device state:"
  fi
  ifconfig $WLAN
  echo "'c' - client mode, 'a' - AP mode, 'e' - exit:"
  read -rsn1 in
  SSID=$(cat /ups/wifi/ssid)
  PASS=$(cat /ups/wifi/pass)
  if [ "$in" = "c" ] || [ "$in" = "C" ]; then
    rm -f "$DNSCFG"
    rm -f "$HOSTAPDCFG"
    echo "Connect to SSID ($SSID):"
    _ssid_pass
    SSSID=$(echo "$SSID" | sed -e 's/[\/&]/\\&/g')
    SPASS=$(echo "$PASS" | sed -e 's/[\/&]/\\&/g')
    cat /ups/wifi/interfaces.sta | sed -e "s/__SSID__/$SSSID/g;s/__PASS__/$SPASS/g;s/__WLAN__/$WLAN/g" > /etc/network/interfaces
    service hostapd stop
    service dnsmasq stop
    service networking restart
  elif [ "$in" = "a" ] || [ "$in" = "A" ]; then
    echo "Advertise SSID ($SSID):"
    _ssid_pass
    SSSID=$(echo "$SSID" | sed -e 's/[\/&]/\\&/g')
    SPASS=$(echo "$PASS" | sed -e 's/[\/&]/\\&/g')
    cat /ups/wifi/interfaces.ap | sed -e "s/__SSID__/$SSSID/g;s/__PASS__/$SPASS/g;s/__WLAN__/$WLAN/g" > /etc/network/interfaces
    cat /ups/wifi/hostapd.conf | sed -e "s/__SSID__/$SSSID/g;s/__PASS__/$SPASS/g;s/__WLAN__/$WLAN/g" > "$HOSTAPDCFG"
    cat /ups/wifi/dnsmasq.conf | sed -e "s/__SSID__/$SSSID/g;s/__PASS__/$SPASS/g;s/__WLAN__/$WLAN/g" > "$DNSCFG"
    service networking restart
    service hostapd restart
    service dnsmasq restart
  elif [ "$in" = "e" ] || [ "$in" = "E" ]; then
    MODE="_main"
  else
    echo "Unrecognized input!"
  fi
}

function _main() {
  echo "'w' - control WiFi, 'p' - control power, 'r'- $MYUSER password."
  read -rsn1 input

  if [ "$input" = "p" ] || [ "$input" = "P" ]; then
    MODE="_power"
  elif [ "$input" = "w" ] || [ "$input" = "W" ]; then
    MODE="_wifi"
  elif [ "$input" = "r" ]; then
    passwd $MYUSER
  elif [ "$input" = "s" ] || [ "$input" = "S" ]; then
    /bin/bash
  else
    echo "Unrecognized input, please choose:"
  fi
}

while true; do

  $MODE

done

