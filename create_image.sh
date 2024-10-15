#!/bin/sh

# Usage: create_image_file <imagefile.img> <size in GB>
create_image_file() {
    rm -rf $1
    dd if=/dev/zero of=$1 bs=1024M count=$2 status=progress && sync
}

# Usage: create_partitions <imagefile.img>
create_partitions() {
    P1=+256M
    P2=+256M
    P3=+256M
    P4=+256M
    P5=+256M
    (
    echo o
    echo n # DOS_PART1
    echo p
    echo 1
    echo
    echo $P1
    echo a
    echo n # EXT_PART2
    echo e
    echo 2
    echo
    echo
    echo n # EXT_PART3
    echo
    echo $P2
    echo n # EXT_PART4
    echo
    echo $P2
    echo n # EXT_PART5
    echo
    echo $P2
    echo n # EXT_PART6
    echo
    echo $P2
    echo n # EXT_PART7
    echo
    echo $P2
    echo n # EXT_PART8
    echo
    echo $P3
    echo n # EXT_PART9
    echo
    echo $P4
    echo n # EXT_PART10
    echo
    echo $P5
    echo n # EXT_PART11
    echo
    echo $P5
    echo w # Write changes
    ) | fdisk $1 > create_image.log
    sync
}

# Usage: create_loop_device <imagefile.img>
create_loop_device() {
    PARTX_LOOP_CREATE=`sudo partx -a -v $1`
    LOOP_NUM=`echo "$PARTX_LOOP_CREATE" | grep -E 'dos' | awk -F '/dev/loop|:' '{print $2}'`
    echo LOOP_NUM:$LOOP_NUM
    PARTITION_CHECK=`echo "$PARTX_LOOP_CREATE" | grep 'partition #'`

PARTITION_CHECK_NEW=$(cat<<EOF
/dev/loop$LOOP_NUM: partition #1 added
/dev/loop$LOOP_NUM: partition #2 added
/dev/loop$LOOP_NUM: partition #5 added
/dev/loop$LOOP_NUM: partition #6 added
/dev/loop$LOOP_NUM: partition #7 added
/dev/loop$LOOP_NUM: partition #8 added
/dev/loop$LOOP_NUM: partition #9 added
/dev/loop$LOOP_NUM: partition #10 added
/dev/loop$LOOP_NUM: partition #11 added
/dev/loop$LOOP_NUM: partition #12 added
/dev/loop$LOOP_NUM: partition #13 added
EOF
)
    if [ "$PARTITION_CHECK" = "$PARTITION_CHECK_NEW" ]; then
        echo "CHECK:pass"
        sync
    else
        echo PARTITION_CHECK:
        echo "$PARTITION_CHECK"
        echo PARTITION_CHECK_NEW:
        echo "$PARTITION_CHECK_NEW"
        echo "CHECK:fail"
        exit 1
    fi
}

mount_partitions() {
    MOUNT_DIRS="DOS_PART1 EXT_PART5 EXT_PART6 EXT_PART7 EXT_PART8 EXT_PART9 EXT_PART10 EXT_PART11 EXT_PART12 EXT_PART13"
    for d in $MOUNT_DIRS; do
        mkdir -p $d
        PART_NUM=`echo $d | awk -F 'PART' '{print $2}'`

        if [ $d = *DOS* ]; then
            sudo mkfs.vfat -F32 -n $d /dev/loop${LOOP_NUM}p${PART_NUM} >> create_image.log
        else
            echo "ext"
            sudo mkfs.ext4 -L $d /dev/loop${LOOP_NUM}p${PART_NUM} >> create_image.log
        fi
        sudo mount /dev/loop${LOOP_NUM}p${PART_NUM} $d
    done
}

unmount_partitions() {
    sync
    MOUNT_POINTS=`mount | grep -E 'loop|DOS_PART|EXT_PART' | awk '{print $3}'`
    for d in $MOUNT_POINTS; do
        sudo umount $d
        rm -rf $d
    done
    sudo partx -d -v /dev/loop${LOOP_NUM}
}

# Usage: dump_partition_table <imagefile.img> <imagefile.table>
dump_partition_table() {
    sfdisk -d $1 > $2
}

# Usage: apply_partition_table <imagefile.img> <imagefile.table>
apply_partition_table() {
    sfdisk $1 < $2
}

create_image_file storage.img 3
create_partitions storage.img
dump_partition_table storage.img storage.table
create_loop_device storage.img
mount_partitions
unmount_partitions

#apply_partition_table storage.img storage.table