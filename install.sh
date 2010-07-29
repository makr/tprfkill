#!/bin/bash
# -- install.sh
#
# Installs tprfkill.tcl to dump and restore the device states during reboot.
#
# Copyright © 2010 Matthias Kraft <M.Kraft@gmx.com>
#
# See the file "license.terms" for information on usage and redistribution.
# -----------------------------------------------------------------------------

SYSADMIN_ID=0
SRC_ROOT="`dirname $0`"

echo "Checking prerequisites ..."

# check for root privileges
if [ `id -u` != $SYSADMIN_ID ]; then
	echo "Installation needs root privileges!" > 2
	exit 1
fi

. "$SRC_ROOT/etc/sysconfig/tprfkill"

# check tclsh version
"$TPRFKILL_TCLSH" << EOS
if {[catch {package r Tcl 8.5} msg]} {
puts stderr \$msg
exit 1
} else {
exit 0
}
EOS

test $? -eq 0 || echo "Warning! TPRFKILL_TCLSH in /etc/sysconfig/tprfkill must be configured!"

echo "Installing scripts ..."

# copy the scripts and make sure they can be executed
install -o root -m 0755 "$SRC_ROOT/tprfkill.tcl" /usr/local/bin/tprfkill.tcl
install -o root -m 0755 "$SRC_ROOT/etc/init.d/tprfkill" /etc/init.d/tprfkill
install -o root -m 0644 "$SRC_ROOT/etc/sysconfig/tprfkill" /etc/sysconfig/tprfkill
install -o root -m 0755 -d /var/lib/tprfkill

echo "Activating service ..."

# Note: This works only for LSB compliant systems. It will very likely not work
# on Redhat Enterprise Linux, because of a bug in their LSB package.

insserv /etc/init.d/tprfkill || echo "Failed to activate the service!" > 2

echo "... done."
