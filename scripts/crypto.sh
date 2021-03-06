#!/bin/sh
#
# Florent Jacquet <florent.jacquet@free-electrons.com>
#

# Default algo list
ALGOS="
digest_null
compress_null
cipher_null
"

# Define here the needed modules given the LAVA device-type
case $1 in
    "sama53d")
        MODULES="
        kernel/drivers/crypto/atmel-sha.ko
        kernel/drivers/crypto/atmel-aes.ko
        kernel/drivers/crypto/atmel-tdes.ko
        "
        # You can add specific algorithms here
    ;;
    "armada-370-db"|"armada-370-rd"|"armada-375-db"|"armada-385-db-ap"|"armada-388-clearfog"|"armada-388-gp"|"armada-xp-db"|"armada-xp-gp"|"armada-xp-linksys-mamba"|"armada-xp-openblocks-ax3-4")
        DRIVER="marvell-cesa"
        MODULES="
        kernel/crypto/des_generic.ko
        kernel/drivers/crypto/marvell/marvell-cesa.ko
        "
        ALGOS="
hmac(sha256)
hmac(sha1)
hmac(md5)
sha256
sha1
md5
cbc(aes)
ecb(aes)
cbc(des3_ede)
ecb(des3_ede)
cbc(des)
ecb(des)
"
    ;;
    # You can add more device-type here
esac

# You don't need to touch anything below this
# =============================================================

echo "#### Beginning crypto test ####"


RETURN_VALUE=0

# We check:
# 1/ if the driver exists builtin
# 2/ if not, if the modules can be inserted successfully
# 3/ if not, we fail
echo "==== Checking if driver is builtin ===="
if [ -d /sys/bus/platform/drivers/$DRIVER ]; then
    echo "Driver $DRIVER exists, skip modules"
else
    echo "==== Driver compiled as modules, try to insert it ===="
    cd /lib/modules/$(uname -r)
    for MODULE in $MODULES; do
	echo "Inserting $MODULE"
	if insmod $MODULE; then
            echo "OK"
	else
            echo "FAIL"
            RETURN_VALUE=1
	fi
    done
fi

echo "==== Doing basic checks ===="

IFS='
'
for ALGO in $ALGOS; do
    ALGO_FOUND=0
    # printf "__________ %-58s __________\n" "Checking algo $ALGO"
    BLOCK=$(grep "name\|selftest" /proc/crypto|grep "$ALGO$" -m 1 -A1)

    # printf "BLOCK\n%s\nEND BLOCK\n" $BLOCK

    for line in $BLOCK; do
        if [ "$line" != "${line#selftest}" ]; then
            ALGO_FOUND=1
            if echo "$line" | grep "passed" > /dev/null; then
                echo "OK: $ALGO correctly registered in /proc/crypto."
            else
                echo "ERROR: $ALGO seems to have a problem in /proc/crypto."
                RETURN_VALUE=1
            fi
        fi
    done
    if [ $ALGO_FOUND -eq 0 ]; then
        echo "ERROR: $ALGO not found in /proc/crypto."
        RETURN_VALUE=1
    fi
    # printf "================================================================================\n\n"
done

echo "==== Checking self-tests ===="

if dmesg | grep "alg: .*est [[:digit:]]\+ failed for "; then
    echo "ERROR: At least one crypto self-tests failed."
    RETURN_VALUE=1
else
    echo "OK: Crypto self-tests did not report any error (or did not run)"
fi


if [ $RETURN_VALUE -eq 0 ]; then
    echo "####     Successful     ####"
else
    echo "#### crypto test had a problem somewhere ####"
fi
echo "#### End of crypto test ####"
exit $RETURN_VALUE


