#!/usr/bin/env tclsh8.5
# --------------------------------------------------------------------------
#
# Copyright © 2010 Matthias Kraft <M.Kraft@gmx.com>.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# --------------------------------------------------------------------------
# TODO: with restore, check if rfkill is available, try to modprobe if not
# TODO: SYSV script

package require Tcl 8.5

namespace eval tprfkill {
	set base "/sys/class/rfkill"
	set store(global) "/etc/tprfkillrc"
	set store(local) "~/.tprfkillrc"
	set store(reload) "/var/lib/tprfkill/states"
	array set defaults {
		bluetooth	soft_blocked
		wwan		keep
		wlan		keep
	}
	array set state2num {
		"soft_blocked"	0
		"unblocked"	1
		"hard_blocked"	2
	}
	array set num2state {
		0	"soft_blocked"
		1	"unblocked"
		2	"hard_blocked"
	}
}

# read the first line from $rfdir/$kind
proc tprfkill::GetLine {rfdir kind} {
	set fn [file join $rfdir $kind]
	if {![file readable $fn]} {
		return -code error "rfkill $kind is not readable"
	}
	set fh [open $fn r]
	set ln [string trim [chan gets $fh]]
	chan close $fh
	return $ln
}

# handle rfkill device type
proc tprfkill::type {subcmd rfdir} {
	variable base
	variable rfkill
	if {$subcmd ne "read"} {
		return -code error "unknown subcmd, must be read"
	}
	# read type
	return [GetLine "$base/$rfdir" "type"]
}

# handle rfkill device name
proc tprfkill::name {subcmd rfdir} {
	variable base
	variable rfkill
	if {$subcmd ne "read"} {
		return -code error "unknown subcmd, must be read"
	}
	# read type
	return [GetLine "$base/$rfdir" "name"]
}

# handle rfkill device state
proc tprfkill::state {subcmd rfdir args} {
	variable base
	variable num2state
	variable state2num
	# read state
	set st [GetLine "$base/$rfdir" "state"]
	if {![info exists num2state($st)]} {
		return -code error "unsupported state"
	}
	set state $num2state($st)
	if {$subcmd eq "read"} {
		return $state
	}
	if {$subcmd eq "set"} {
		lassign $args newstate
		if {![string is integer -strict $newstate]} {
			if {![info exists state2num($newstate)]} {
				return -code error "unsupported state"
			}
			set newstate $state2num($newstate)
		} elseif {![info exists num2state($newstate)]} {
			return -code error "unsupported state"
		}
		set fn [file join $base $rfdir state]
		if {![file writable $fn]} {
			return -code error "state is not writable"
		}
		if {$st == 2} {
			return -code error "software cannot override a hard_block"
		} elseif {$newstate == 2} {
			return -code error "software cannot set a hard_block"
		}
		set fh [open $fn w]
		chan puts $fh $newstate
		chan close $fh
		return $state
	}
}

# read and print all states
proc tprfkill::read {} {
	foreach {name type rfkill state} [Read 0] {
		puts "$name ($type) at $rfkill is $state"
	}
}

# read current states and return result list with 4 entries per device:
# name type file state
proc tprfkill::Read {fail} {
	variable base
	set rc [expr {$fail ? "error" : "continue"}]
	set result {}
	foreach d [glob -dir $base -tails -- rfkill*] {
		if {[catch {type read $d} type]} {
			 Error $rc "cannot determine type of $d: $type"
		}
		if {[catch {name read $d} name]} {
			Error $rc "cannot read name of $d: $name"
		}
		if {[catch {state read $d} state]} {
			Error $rc "cannot read state of $d: $state"
		}
		lappend result $name $type $d $state
	}
	return $result
}

# either print error and return with code rc, or if rc is "error", flag error
# and set error msg
proc tprfkill::Error {rc msg} {
	if {$rc ne "error"} {
		puts stderr $msg
		return -code $rc
	} else {
		return -code error $msg
	}
}

# reset all states to the default values
proc tprfkill::reset {} {
	variable defaults

	foreach {n t f s} [Read 1] {
		if {[info exists defaults($n)]} {
			# ok we have a setting by the device's name
			set k $n
		} elseif {[info exists defaults($t)]} {
			# ok we have a setting for a type like this
			set k $t
		} else {
			# nothing found, skip
			continue
		}
		if {($defaults($k) eq "keep") || ($defaults($k) eq $s)} {
			# we should either not touch this device, or the state
			# is already the requested one
			continue
		}
		if {[catch {state set $f $defaults($k)} state]} {
			puts stderr "cannot set state of device $f ($k): $state"
		} else {
			puts "$k at $f is now $defaults($k) was $s"
		}
	}
}

# save current states to local configuration
proc tprfkill::save {} {
	variable store
	# get the current values
	set currentStates [Read 1]
	# backup existing settings
	if {[file exists $store(local)]} {
		file rename -force -- $store(local) ${store(local)}~
	}
	# store the current values
	set fh [open $store(local) w]
	chan configure $fh -encoding utf-8
	chan puts $fh "# tprfkill settings - saved at [Timestamp {}]"
	foreach {n t f s} $currentStates {
		chan puts $fh "# ${f}: ${t}"
		chan puts $fh "${n} = ${s}"
	}
	chan close $fh
}

# dump current status of the rfkill devices to an independent file
proc tprfkill::dump {} {
	variable store
	set entries {}
	set dir [file dirname $store(reload)]
	if {![file isdirectory $dir]} {
		file mkdir $dir
	}
	set fh [open $store(reload) w]
	chan configure $fh -encoding utf-8
	foreach {n t f s} [Read 0] {
		lappend entries [join [list $n $s] "="]
	}
	chan puts -nonewline $fh [join $entries ";"]
	chan close $fh
}

# restore the previously dumped status of the rfkill devices
proc tprfkill::restore {} {
	variable store
	variable defaults
	if {![file exists $store(reload)]} {
		return -code error "cannot find previously dumped settings"
	}
	set fh [open $store(reload) r]
	chan configure $fh -encoding utf-8
	set dump [chan read $fh]
	chan close $fh
	array unset defaults
	foreach entry [split $dump ";"] {
		array set defaults [split $entry "="]
	}
	reset
}

# format a timestamp, results in e.g. "2010-07-16 22:19:49 CEST"
proc tprfkill::Timestamp {seconds} {
	if {$seconds eq ""} {
		set seconds [clock seconds]
	}
	clock format $seconds -format "%Y-%m-%d %T %Z"
}

# load configuration and start requested operation
# note: Main returns exit codes: 0 => ok, 1 => failure
proc tprfkill::Main {args} {
	variable config

	LoadDefaults
	if {![Config {*}$args]} {
		return 1
	}

	if {[catch $config(action) msg]} {
		puts stderr "could not $config(action) rfkill states: $msg"
		return 1
	}
	return 0
}

# if available load global settings, then local, last one wins
proc tprfkill::LoadDefaults {} {
	variable store
	foreach f [list $store(global) $store(local)] {
		if {[file readable $f] &&
		    [catch {LoadFile $f} msg]} {
			puts stderr "cannot load rfkill settings from $f: $msg"
		}
	}
}

# load requested configuration and overwrite program defaults
proc tprfkill::LoadFile {file} {
	variable defaults
	set fh [open $file r]
	chan configure $fh -encoding utf-8
	while {![chan eof $fh]} {
		if {[chan gets $fh line] > 0} {
			# look if there is a comment character in the line
			set cstart [string first "#" $line]
			if {$cstart >= 0} {
				# remove comment
				set line [string range $line 0 [expr {$cstart - 1}]]
			}
			# remove surrounding whitespace
			set line [string trim $line]
			# expect a property style line
			if {[regexp -- {^(\w+)\s*=\s*(\w+)} $line -> k v]} {
				set newdef($k) $v
			}
		}
	}
	chan close $fh
	if {[info exists newdef]} {
		# file has been read successfully, override defaults array
		array set defaults [array get newdef]
	}
}

# configure operation as requested on command line
proc tprfkill::Config {args} {
	variable config
	set subcmd [lindex $args 0]
	set args [lrange $args 1 end]
	if {$subcmd eq "read"} {
		set config(action) "read"
	} elseif {$subcmd eq "reset"} {
		set config(action) "reset"
	} elseif {$subcmd eq "save"} {
		set config(action) "save"
	} elseif {$subcmd eq "all"} {
		lassign $args newstate
		if {![string is boolean -strict $newstate]} {
			Usage
		}
		if {$newstate} {
			set newstate "unblocked"
		} else {
			set newstate "soft_blocked"
		}
		foreach k [array names defaults] {
			set defaults($k) $newstate
		}
		set config(action) reset
	} elseif {$subcmd eq "dump"} {
		set config(action) "dump"
	} elseif {$subcmd eq "restore"} {
		set config(action) "restore"
	} else {
		Usage
	}
	return 1
}

# print a short usage information and exit
proc tprfkill::Usage {} {
	variable store
	puts stderr "$::argv0 subcmd \[options\]\nsubcmds:"
	puts stderr " read    - read rfkill states and print them"
	puts stderr " save    - save rfkill states to $store(local)"
	puts stderr " reset   - reset rfkill states to program defaults"
	puts stderr " all off - switch all rfkill devices off"
	puts stderr " all on  - switch all rfkill devices on (if possible)"
	puts stderr " dump    - dump rfkill states to persistent store"
	puts stderr " restore - restore rfkill states from persistent store"
	return -code return 0
}

if {![info exists ::tcl_interactive] || !$::tcl_interactive} {
	# start program automatically only if not sourced in a tclsh
	exit [tprfkill::Main {*}$::argv]
}
