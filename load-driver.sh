#!/bin/bash

INTERFACE=$(cat release-info.txt | grep INTERFACE | sed -e 's/INTERFACE=\([a-zA-Z]\+\).*/\1/')
FWNAME=$(cat release-info.txt | grep -e FWNAME | sed -e 's/FWNAME=\(.*\)/\1/')

# This is an example on how to load the driver. Refer to the wifi_src or mbt_src
# to have a full list of the module parameters

echo "Loading Wifi driver"
sudo modprobe cfg80211 2> /dev/null
sudo insmod mlan.ko
FWPARAM="fw_name=nxp/$FWNAME"
if [ "$INTERFACE" == "usb" ]; then
	sudo insmod usbfwdnld.ko $FWPARAM
	FWPARAM=""
fi
if [ "$INTERFACE" == "sdio" ]; then
	sudo modprobe mmc_core 2> /dev/null
	INTERFACE="sd"
fi
sudo insmod ${INTERFACE}8xxx.ko drv_mode=3 mfg_mode=0 $FWPARAM cal_data_cfg=none cfg80211_wext=0x0f reg_alpha2=US cntry_txpwr=1 host_mlme=1

echo "Loading Bluetoth driver"
sudo modprobe bluetooth 2> /dev/null
sudo insmod bt8xxx.ko
 
