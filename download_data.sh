#!/bin/bash

set -o nounset

# This tool is space hungry!
# Basically if fetches ARCHIVES.gz (~2.5GB extracted) from currently developed Leap,
# and filters translatable files. Fetches binary rpms from the Leap oss repo, extracts individual files 
# and generates compendium of all translations.
# 
# Right now we only extract .mo files.
#
# WARNING: Runtime can take a few hours (mostly downloading and later cpio extraction)
# and will consume around 10GB in `pwd`/download in total !!!

#VERSION=
URI="https://download.opensuse.org/tumbleweed/repo/oss/"
# needed only for the tar.bz archive name
# https://serverfault.com/questions/557350/parse-an-rpm-name-into-its-components
function parse_rpm() { RPM=$1;B=${RPM##*/};B=${B%.rpm};A=${B##*.};B=${B%.*};R=${B##*-};B=${B%-*};V=${B##*-};B=${B%-*};N=$B;echo "$N"; }

if [ ! -f "ARCHIVES" ]; then
    wget $URI/ARCHIVES.gz
    gunzip ARCHIVES.gz
fi

# limit it to only x86_64 and noarch
if [ ! -f "filtered_arches.txt" ]; then
    echo "Filtering only applicable arches"
    egrep "^\./x86_64|^\./noarch" ARCHIVES > filtered_arches.txt
fi

if [ ! -f "package_names.txt" ]; then
    echo "Fetching list of package names"
    grep "Name  *:" filtered_arches.txt > package_names.txt
fi

if [ ! -f "matched_files.txt" ]; then
    echo "Looking up translatable file entries"
    egrep "\.mo$" filtered_arches.txt > matched_files.txt
fi

declare -A filelists

# ./noarch/grub2-powerpc-ieee1275-2.06-150500.29.8.1.noarch.rpm:    drwxr-xr-x    2 root    root                        0 Oct 11 12:15 /usr/share/grub2/powerpc-ieee1275
echo "Processing translatable file entries"
while read line; do
    entry_rpm=`echo $line | awk '{ print $1}' | sed -s "s/://" `
    entry_file=`echo $line | awk '{ print $NF}'`
    [ "${filelists[$entry_rpm]+abc}" ] && filelists[$entry_rpm]="${filelists[$entry_rpm]} $entry_file" || filelists[$entry_rpm]="$entry_file"
done < "matched_files.txt"

mkdir -p download
mkdir -p download/cache
echo "Getting binaries"
for key in "${!filelists[@]}"; do
    if test -f download_done.stamp ; then break ; fi
    entry_arch=`echo $key | awk -F "/" '{ print $2}'`
    entry_rpm=`echo $key | awk -F "/" '{ print $NF}' | sed -s "s/://"`
    entry_name=`grep $key package_names.txt | awk '{ print $NF }'`
    rpm_path=`echo $key | sed "s/^.//"`
    if [ ! -f "download/cache/$entry_rpm" ]; then
        wget -P download/cache $URI/$rpm_path
    fi
    for path in ${filelists[$key]}; do
        cachedir="`pwd`/download/cache"
        srpm=`rpm --query $cachedir/$entry_rpm  --queryformat "%{SOURCERPM} %{name}"`
        srpm_name=`parse_rpm $srpm`
        tgdir="`pwd`/download/extracted/$srpm_name"
        mkdir -p $tgdir
        pushd $tgdir > /dev/null
        rpm2cpio "$cachedir/$entry_rpm" | cpio -idv ".${path}"
        popd >/dev/null
    done
done
touch download_done.stamp

echo "Unpacking messages"
find "`pwd`/download/extracted/" -name *.mo |
    while read MO; do
        if test -f mo_done.stamp ; then break ; fi
        msgunfmt "$MO" -o ${MO%.mo}.po
    done
touch mo_done.stamp

echo "Creating compendium"
tgdir="`pwd`/compendium"
find "`pwd`/download/extracted" -type f -name "*.po" >mo_files.lst
exec 3<mo_files.lst
let i=0
while read -u3 FILE ; do
    case $FILE in
    */LC_MESSAGES/*.po )
        LNG=${FILE%/LC_MESSAGES/*.po}
        LNG=${LNG##*/}
        ;;
    */locale/*/*.po )
        LNG=${FILE%/*.po}
        LNG=${LNG##*/}
        ;;
    * )
        echo "Unknown path type for $FILE"
        exit 1
        ;;
    esac
    eval FILELIST_$LNG\[i\]=\"\$FILE\"
    let i++
done
exec 3<-

mkdir -p "$tgdir"
pushd "`pwd`/download/extracted/" >/dev/null
for VAR in ${!FILELIST_*} ; do
    LNG=${VAR#FILELIST_}
    eval msgcat -o "$tgdir/$LNG.po" \${$VAR\[@\]}
done
popd >/dev/null
