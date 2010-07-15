#!/usr/bin/env tclsh8.5
# --------------------------------------------------------------------------
#
# Copyright © 2010 Matthias Kraft <M.Kraft@gmx.com>.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# --------------------------------------------------------------------------

package require Tcl 8.5

namespace eval tprfkill {
	set base "/sys/class/rfkill"
	set store(global) "/etc/tprfkillrc"
	set store(local) "~/.tprfkillrc"
	set store(reload) "/var/lib/tprfkill/states"
	array set defaults {
		bluetooth,state	soft_blocked
		wwan,state	keep
		wlan,state	keep
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

proc tprfkill::type {subcmd rfdir} {
	variable rfkill
	if {$subcmd ne "read"} {
		return -code error "unknown subcmd, must be read"
	}
	# read type
	return [GetLine $rfdir "type"]
}

proc tprfkill::name {subcmd rfdir} {
	variable rfkill
	if {$subcmd ne "read"} {
		return -code error "unknown subcmd, must be read"
	}
	# read type
	return [GetLine $rfdir "name"]
}

proc tprfkill::state {subcmd rfdir args} {
	variable num2state
	variable state2num
	# read state
	set st [GetLine $rfdir "state"]
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
		set fn [file join $rfdir state]
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

proc tprfkill::read {} {
	variable base
	foreach d [glob -dir $base -tails -- rfkill*] {
		if {[catch {type read "$base/$d"} type]} {
			puts stderr "cannot determine type of $d: $type"
			continue
		}
		if {[catch {name read "$base/$d"} name]} {
			puts stderr "cannot read name of $d: $name"
			continue
		}
		if {[catch {state read "$base/$d"} state]} {
			puts stderr "cannot read state of $d: $state"
			continue
		}
		puts "$name ($type) at $d is $state"
	}
}

proc tprfkill::reset {} {
	return -code error unimplemented
	if {[catch {state set $d $defaults($type,state)} state]} {
		puts stderr "cannot set state of $type device: $state"
		continue
	}
	puts "$type at [file tail $d] was $state, now $defaults($type,state)"

}

proc tprfkill::Main {args} {
	variable config

	LoadDefaults
	Config {*}$args

	if {[catch $config(action) msg]} {
		puts stderr "could not $config(action) rfkill states: $msg"
		exit 1
	}
}

proc tprfkill::LoadDefaults {} {
	variable store
	foreach f [list $store(global) $store(local)] {
		if {[file readable $f] &&
		    [catch {LoadFile $f} msg]} {
			puts stderr "cannot load rfkill settings from $f: $msg"
		}
	}
}

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
}

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
	exit 1
}

tprfkill::Main {*}$::argv
