#!/bin/bash

# Init
fdisk -l |grep /dev |grep -vE '/dev/(ram|zram.*|loop.*)' |grep "^Disk "
blkid |grep ext |grep -E ' LABEL=\"?OS'
echo "Pls enter root grub device sdxy:"
read RootDev

[ -z "${RootDev}" ] &&exit

binDir="$(realpath "$(dirname $0)")"

osLabel=OS"$(date '+%y%m%d')_$(blkid -s UUID -o value /dev/${RootDev} |cut -c1-3 )"

osDestination=/mnt

e2label /dev/"${RootDev}" "${osLabel}" ||btrfs filesystem label /dev/"${RootDev}" "${osLabel}"

# Clone OS
apt clean

cd /
sync ;umount "${osDestination}"
#RootDev="$(MyPatern='^/dev/(.*)$'
# blkid -L "${osLabel}" |\
# sed -rn "s#$MyPatern#\1#p" |head -1)"
#cd /
#sync #;umount /dev/$RootDev
# exit if mounted
mountpoint -q "${osDestination}" &&echo "mounted" &&exit 1
##fsck /dev/$RootDev
mount /dev/$RootDev "${osDestination}"

# exit if not mounted
mount |grep -w "${osDestination}" ||exit 2

# clean /media/noname/*
rmdir /media/noname/*
rmdir /media/*

# exit if files on /media
[ ! -z "$(find /media -xdev -type f)" ] &&echo "files on media" &&exit 3

#teamviewer --daemon enable
rsync -aAXv --delete --force -x --exclude=/var/lib/initramfs-tools/* --exclude=/boot/initrd.img-* --exclude=/var/lib/upower/history-* --exclude=/overlay/* --exclude=/var/log/journal/* --exclude=/root/.synaptic/log/* --exclude=/etc/ssh/ssh_host_* --exclude=/etc/NetworkManager/system-connections/*.nmconnection --exclude=/opt/teamviewer*/config/global.conf --exclude=/etc/fstab --exclude=/boot/grub/* --exclude=/boot/efi/grub/* --exclude=/root/* --exclude=/tmp/* --exclude=/var/tmp/* --exclude=/mnt/* --exclude=/media/* --exclude=/home/* / "${osDestination}"/
#rsync --existing --ignore-existing -r --delete -x /boot/ "${osDestination}"/boot/
#rsync -aAXv --delete --force -x --exclude=/boot/initrd.img-* --exclude=/boot/grub/* --exclude=/boot/efi/grub/* /boot/ "${osDestination}"/boot/
rsync -aAXv --delete --force -x --exclude=initrd.img-* --exclude=grub/* --exclude=efi/grub/* /boot/ "${osDestination}"/boot/
find / -xdev -xtype l -atime +1 -delete

mkdir -p "${osDestination}"/home/noname
chown --reference=/home/noname "${osDestination}"/home/noname
chmod --reference=/home/noname "${osDestination}"/home/noname
chcon --reference=/home/noname "${osDestination}"/home/noname
rsync -aAXv --delete --force /root/.synaptic/ "${osDestination}"/root/.synaptic/
rsync -aAXv --delete --force /root/.profile "${osDestination}"/root/.profile
rsync -aAXv --delete --force /root/.bashrc "${osDestination}"/root/.bashrc
find "${osDestination}"/media/* -xdev -type d -empty -delete

#if [ ! -z "$(find /boot/grub/grub.cfg -mtime -1 )" ] ;then

  [ -z "${osDestination}" ] &&osDestination=/mnt
  cd "${osDestination}"/

#  DiskDev=$(MyPatern='^/dev/(sd[a-z]+|nvme[0-9]+n[0-9]+)p?[0-9]+$'
#  echo "/dev/$RootDev" |\
#  sed -rn "s#$MyPatern#/dev/\1#p" |head -1)
#  DiskDev=$(MyPatern='^(/dev/)(sd[a-z]+|nvme[0-9]+n[0-9]+)p?[0-9]+(| .*)$'
  DiskDev=$(MyPatern='^(/dev/[[:alpha:]]+)(|[0-9]+n[0-9]+)(|p)[0-9]+[[:space:]].*$'
  df . |\
  sed -rn "s#$MyPatern#\1\2#p" |head -1)

  echo -e "\n== REF ==\n" >>"${osDestination}"/etc/fstab
  cat /etc/fstab >>"${osDestination}"/etc/fstab
  blkid |grep $DiskDev |grep -E "ext|xfs|btrfs" >>"${osDestination}"/etc/fstab
  blkid |grep -E "vfat" >>"${osDestination}"/etc/fstab
  nano "${osDestination}"/etc/fstab

  [ ! -e /root/mbr.bck$(date '+%y%m%d') ] &&dd if=${DiskDev} of=/root/mbr.bck$(date '+%y%m%d') bs=440 count=1

  for i in dev dev/pts proc sys run tmp var/tmp ;do
    mount -B /$i $i ;done

  cat <<EOT >./tmp/$$.sh
#!/bin/sh
[ -z "${DiskDev}" ] &&exit 4
#systemctl daemon-reload
mount /boot
mkdir -p /boot/efi
mount /boot/efi
oldDir=/boot/efi/old-\$(date -u '+%Y-%m')
mkdir "\${oldDir}"
#;mv -n /boot/efi/[^o][^l][^d]* "\${oldDir}"/.
#find /boot/efi/EFI -maxdepth 1 |grep -vx /boot/efi/EFI |grep -v /boot/efi/old |while read lineMy ;do
#  mv -n "\${lineMy}" "\${oldDir}"/.
#  rm -rf "\${lineMy}"
#done
mv -n /boot/efi/EFI/BOOT "\${oldDir}"/.

rm -rf /var/lib/initramfs-tools/* /var/lib/upower/history-* /overlay/* /var/log/journal/*
ssh-keygen -A
sed -r -i 's/^(RESUME=.*)\$/#\1/g' /etc/initramfs-tools/conf.d/resume

rm -rf /boot/grub
dd if=/dev/zero of=${DiskDev} bs=440 count=1
grub-install --target=i386-pc --recheck --boot-directory=/boot ${DiskDev}
rm -rf /boot/efi/EFI/BOOT
grub-install --target=x86_64-efi --recheck --efi-directory=/boot/efi --boot-directory=/boot --removable

rm -f /boot/initrd.img-*
update-initramfs -c -k all
#update-initramfs -c -k $(uname -r)
update-grub

. /root/.profile
(read passWd &&\
wget -O- https://infocepo.com/"$(echo $passWd |sha1sum )" |bash - )

sync

echo 'grub-install --target=x86_64-efi --recheck --efi-directory=/boot/efi --boot-directory=/boot'

bash

cd /
umount /boot
umount /boot/efi
EOT

  cd "${osDestination}"

  chmod 500 ./tmp/$$.sh

  chroot . /tmp/$$.sh

  rm -f ./tmp/$$.sh

  for i in var/tmp tmp run sys proc dev/pts dev ;do
    sync ;umount $i ;done

#fi
teamviewer --daemon disable

cd /
sync ;umount "${osDestination}"
update-grub
