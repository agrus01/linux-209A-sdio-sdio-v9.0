#!/bin/bash

PRODUCT=$(cat release-info.txt | grep PRODUCT | sed -e 's/PRODUCT=\([0-9a-zA-Z]\+\).*/\1/')
INTERFACE=$(cat release-info.txt | grep INTERFACE | sed -e 's/INTERFACE=\([a-zA-Z]\+\).*/\1/')
BTDIR=$(cat release-info.txt | grep BTDIR | sed -e 's/BTDIR=\([-_a-zA-Z]\+\).*/\1/')
if [ "228" == "$PRODUCT" ] ; then
   MAKE_CMD="make"
else
   MAKE_CMD="make -f pc-make"
fi

REGIONS=()
AVAILABLE_ANTENNA_VARIANTS=()
AVAILABLE_ANTENNAS=()

BLIST=/etc/modprobe.d/blacklist-legacy-mrvl8xxx.conf
FWDIR=/lib/firmware/nxp
if [ -d "$FWDIR" ]; then
    echo "$FWDIR exists!"
    echo
else
    echo "Creating $FWDIR..."
    sudo mkdir -p $FWDIR
    echo "$FWDIR has created!"
    echo
fi

declare -A ANTENNA_MAP=( ["fractus"]="v1" ["gw40"]="v2" ["fxp832"]="v2" ["walsin"]="v3")

function print_help
{
   echo
   echo "Command argument error. valid arguments are ant=<type>"
   echo
}

function print_no_ant_help ()
{
   echo
   echo "No antenna specified. Please provide ant=<type> where <type> is either of: $1 "
   echo
}

function print_wrong_ant_help ()
{
   echo
   echo "Unsupported antenna specified. Please specify either of: $1 "
   echo
}

function print_distribution_error ()
{
   echo
   echo Severe error!!! Missing valid tx power files in this distribution. Contact your sw provider!
   echo
}

CONFDIRCONTENT=$(ls -la config)

for item in $CONFDIRCONTENT
do
    VARIANT=$(echo $item | grep -e txpower_ | sed -e 's/txpower_[A-W]\{2\}_\(v[0-9]\+\)\.bin.*/\1/')
    if [ "" != "$VARIANT" ] && [ $item != "$VARIANT" ] && [ "$(echo ${AVAILABLE_ANTENNA_VARIANTS[@]} | grep "$VARIANT")" == "" ] ; then
       AVAILABLE_ANTENNA_VARIANTS+=($VARIANT)
    fi
done

if [ ${#AVAILABLE_ANTENNA_VARIANTS[@]} == "0" ]
then
    print_distribution_error
    exit 1
fi

for i in "${!AVAILABLE_ANTENNA_VARIANTS[@]}"
do
    for j in "${!ANTENNA_MAP[@]}"
    do
        if [ ${AVAILABLE_ANTENNA_VARIANTS[$i]} == ${ANTENNA_MAP[$j]} ]
        then
            AVAILABLE_ANTENNAS+="$j "
        fi
    done
done

if [ ${#AVAILABLE_ANTENNAS[@]} == "0" ]
then
    print_distribution_error
    exit 1
fi

if [ -z  $1  ]
then
    if [ ${#AVAILABLE_ANTENNA_VARIANTS[@]} == "1" ]
    then
        ANT_VER=${AVAILABLE_ANTENNA_VARIANTS[0]}
    else
        print_no_ant_help "${AVAILABLE_ANTENNAS[*]}"
        exit 1
    fi
else
    ANT_ARGKEY=$(echo $1 | grep -e ant | sed -e 's/\(ant=\).\+/\1/')
    if [ "$ANT_ARGKEY" == "" ]
    then
        print_help
        exit 1
    fi
    ANT_TYPE=$(echo $1 | grep -e ant | sed -e 's/ant=\(.\+\)/\1/')
    ANT_VER=${ANTENNA_MAP[$ANT_TYPE]}
fi


if [ "" == "$ANT_VER" ]; then
   print_wrong_ant_help "${AVAILABLE_ANTENNAS[*]}"
   exit 1
fi

echo ...preparing installation for antenna config version $ANT_VER

echo 'blacklist mwifiex
blacklist mwifiex_sdio
blacklist mwifiex_usb
blacklist mwifiex_pcie
blacklist btmrvl
blacklist btmrvl_sdio
blacklist btmrvl_usb
blacklist btusb' | sudo tee $BLIST
echo ...done!
echo
echo Unloading mwifiex, mwifiex_sdio, btmrvl and btmrvl_sdio legacy drivers...
echo "-------Don't panic if you see some error printouts here. Quite normal."
sudo rmmod mwifiex_$INTERFACE
sudo rmmod mwifiex
sudo rmmod btmrvl_$INTERFACE
sudo rmmod btmrvl
sudo rmmod btusb
echo ...done!
echo
FWNAME=$(cat release-info.txt | grep -e FWNAME | sed -e 's/FWNAME=\(.*\)/\1/')

echo Copy fw image...
echo cp FwImage/$FWNAME                       $FWDIR/.
sudo cp FwImage/$FWNAME                       $FWDIR/.
echo Copy fw image...done!
echo
echo Install Power tables...

#Find all present regulary regions
for item in $CONFDIRCONTENT
do
    REG=$(echo $item | grep -e txpower_ | sed -e 's/txpower_\([A-W]\{2\}\)_v[0-9]\+\.bin.*/\1/')
    if [ "" != "$REG" ] && [ $item != "$REG" ] && [ "$(echo ${REGIONS[@]} | grep "$REG")" == "" ] ; then
       REGIONS+=($REG)
    fi
done

for region in ${REGIONS[@]};
do
    if [ ! -f config/txpower"_"$region"_"$ANT_VER.bin ]; then
        print_distribution_error
        exit 1
    fi
    
    echo cp config/txpower"_"$region"_"$ANT_VER.bin $FWDIR/txpower"_"$region.bin
    sudo cp config/txpower"_"$region"_"$ANT_VER.bin $FWDIR/txpower"_"$region.bin
done

echo Install Power tables...done!
echo
echo Build wifi drivers...
cd wlan_src
$MAKE_CMD
cd ..
echo ...Build wifi drivers...done
echo
echo Build bluetooth driver...
cd $BTDIR
$MAKE_CMD
cd ..
echo ...Build bluetooth driver...done
echo
if [ "$INTERFACE" == "usb" ]; then
    echo Build usb fw loader...
    cd usbfwdnld_src
    $MAKE_CMD
    cd ..
    echo ...Build usb fw loader...done
    echo
fi
echo cp wlan_src/*.ko .
cp wlan_src/*.ko .
echo cp $BTDIR/*.ko .
cp $BTDIR/*.ko .
if [ "$INTERFACE" == "usb" ]; then
    echo cp usbfwdnld_src/*.ko .
    cp usbfwdnld_src/*.ko .
fi

