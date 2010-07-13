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

proc tprfkill::Main {args} {
	variable base
	variable defaults
	foreach d [glob -dir $base -- rfkill*] {
		if {[catch {type read $d} type]} {
			puts stderr "unsupported rfkill device at $d: $type"
			continue
		}
		if {[catch {state read $d} state]} {
			puts stderr "cannot read state of $type device: $state"
			continue
		}
		if {($defaults($type,state) eq "keep") ||
			($defaults($type,state) eq $state)} {
			puts "$type at [file tail $d] is $state"
			continue
		}
		if {[catch {state set $d $defaults($type,state)} state]} {
			puts stderr "cannot set state of $type device: $state"
			continue
		}
		puts "$type at [file tail $d] was $state, now $defaults($type,state)"
	}
}

tprfkill::Main {*}$::argv
