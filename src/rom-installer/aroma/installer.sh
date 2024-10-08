#!/sbin/sh

# get the flipping functions and flashables from the file.
source /tmp/functions.sh
source /tmp/flasher.items

mkdir -p /tmp/system
mount -o rw /dev/block/by-name/system /tmp/system || abortInstance --common flasher.failed.system.mount
if [ ! -f "/tmp/system/system/build.prop" ]; then 
    consolePrint --common flasher.dontwipe0
    abortInstance --common flasher.dontwipe1
fi
consolePrint --common flasher.welcome
consolePrint --common flasher.verifying
[ "$(grep_prop "ro.tsukika.buildid" "/tmp/system/system/build.prop")" != "$(grep_prop "flasher.supported.older.version.build.id" "/tmp/common.lang")" ] && \
    abortInstance --common flasher.unsupported.buildid
[ "$(acpi)" -le "35" ] && abortInstance --common flasher.charge.atleast
set -- $flashables
while [ "$1" ]; do
    image="$1"
    shift
    delimiter="$1"
    shift
    target="$1"
    shift
    shift
    imageType="$1"
    shift
    if [ "$delimiter" = "->" ]; then
        consolePrint "Patching $(basename "${image}" .img) image unconditionally..."
        installImages "$image" "$target" "${imageType}"
    else
        debugPrint "Error: Expected '->' but got '$delimiter'"
        abortInstance --common flasher.undefined
    fi
done
if [ "$(getAromaProp "selected.0")" == "1" ]; then
    consolePrint --common flasher.handling.aroma.actions
    # implement your own actions here, item.1.0 -> first item in the first choice box.
    # checkbox0.prop -> first choice box.
fi