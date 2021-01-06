#/bin/bash
## AutoMountUSB.bash
## set -x
## USE THIS WITH EXTREME CAUTION AND NOT ON PRODUCTION SYSTEMS!!
## READ THE ENTIRE SCRIPT AND UNDERSTAND WHAT IT WILL BE DOING TO YOUR SYTEM BEFORE USING IT
##
## This script will add USB storage to an ESXi 7.0 host.
## For this script to work you will need add the USB storage during this script
## This script will NOT DO ANY ERROR CHECKING
clear
cd /tmp
## Clean up any old files
rm /tmp/MyDisks01 2>/dev/null
rm /tmp/MyDisks02 2>/dev/null
rm /tmp/MyUSB01 2>/dev/null
rm /tmp/MyUSB02 2>/dev/null
##
## Do basic setup work for USB
/etc/init.d/usbarbitrator stop
chkconfig usbarbitrator off
##
## get list of USB devices before new storage is added
echo -e \n list of USB devices currently on system
lsusb | sort
lsusb | sort | grep Bus | sort > /tmp/MyUSB01
##
## get list of disks before new storage is added
echo -e \n list of disks devices currently on system
ls /dev/disks | grep mpx | sort
ls /dev/disks | grep mpx | sort > /tmp/MyDisks01
read -p  "Insert the new storage device and Press [Enter] key to continue "
##
## loop until new storage is found
QuitProg=0
LoopI=0
while [ $LoopI -eq 0 ]
do
  if [[ $QuitProg -eq 1 ]]
    then
      exit
  fi
## get list of disks after storage has been added
ls /dev/disks | grep mpx | sort > /tmp/MyDisks02
##
## compare files to get new storage device. First check if there are any differences, if not exit.
diff /tmp/MyDisks01 /tmp/MyDisks02 > /dev/null
if [[ $? == 0 ]]
  then
      echo -e " \n New Storage not found. To try again enter Y, or enter q to quit"
      read TryAgain
      if [[ $TryAgain != Y ]]
         then
           let QuitProg=1
      fi
  else
      let LoopI=1
fi
done
##
##
echo  New USB Device found
lsusb | sort | grep Bus | sort > /tmp/MyUSB02
diff /tmp/MyUSB01 /tmp/MyUSB02 | grep ^+Bus | sed s/^.//
echo  New Storage found
NewDisk=`diff /tmp/MyDisks01 /tmp/MyDisks02 | grep ^+mpx | grep 0$ | sed s/^.//`
## TJF uncomment this next line to test script
## NewDisk=mpx.vmhba33:C0:T0:L0
echo  The new disk is $NewDisk
echo  The new disk is $NewDisk
partedUtil mklabel /dev/disks/$NewDisk gpt
## Calculate end sector
DiskSize=`partedUtil getptbl /dev/disks/$NewDisk | head -2 | tail -1 | cut -f 1 -d  `
NewDS=$(($DiskSize * 255 * 63 -1))
echo  End of new disk it $NewDS
echo  Below is a list of the volumes currently on your system
esxcli storage vmfs extent list | cut -f 1 -d
echo -n -e \n Enter name of new volume here. Do not use spaces in volume name. ==>
read VName
echo -e \n Name of new volume will be $VName
##
partedUtil setptbl /dev/disks/$NewDisk gpt 1 2048 $NewDS AA31E02A400F11DB9590000C2911D1B8 0
## format the partition with a VMFS 6 filesystem on the device by entering
vmkfstools -C vmfs6 -S $VName /dev/disks/$NewDisk:1
## Display more information about the filesystems on the ESXi host
echo -e \n list filesystems
esxcli storage filesystem list
echo -e \n list vmfs
esxcli storage vmfs extent list
## Clean up any old files
rm /tmp/MyDisks01
rm /tmp/MyDisks02
rm /tmp/MyUSB01
rm /tmp/MyUSB02
echo -e \n Storage Script Finished \n
