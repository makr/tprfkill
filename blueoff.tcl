#!/usr/bin/env tclsh8.5
package require Tcl 8.5

set rfkill(1,type) "bluetooth"
set rfkill(2,type) "wwan"
set rfkill(3,type) "wlan"
set rfkill(1,name) "tpacpi_bluetooth_sw"
set rfkill(2,name) "tpacpi_wwan_sw"
set rfkill(3,name) "phy0"
set rfkill(bluetooth,state) soft_blocked
set rfkill(wwan,state) keep
set rfkill(wlan,state) soft_blocked
set rfkill(base) "/sys/class/rfkill"

proc type {subcmd rfdir} {
	variable rfkill
	if {$subcmd ne "read"} {
		return -code error "unknown subcmd, must be read"
	}
	# read type
	set fn [file join $rfdir type]
	if {![file readable $fn]} {
		return -code error "type is not readable"
	}
	set fh [open $fn r]
	set type [string trim [chan gets $fh]]
	chan close $fh
	# verify type
	foreach t [array names rfkill *,type] {
		if {$type eq $rfkill($t)} {
			return $type
		}
	}
	return -code error "unsupported type"
}

proc state {subcmd rfdir args} {
	# read state
	set fn [file join $rfdir state]
	if {![file readable $fn]} {
		return -code error "state is not readable"
	}
	set fh [open $fn r]
	set st [string trim [chan gets $fh]]
	chan close $fh
	switch -- $st {
		0 {set state "soft_blocked"}
		1 {set state "unblocked"}
		2 {set state "hard_blocked"}
		default {return -code error "unsupported state"}
	}
	if {$subcmd eq "read"} {
		return $state
	}
	if {$subcmd eq "set"} {
		if {![file writable $fn]} {
			return -code error "state is not writable"
		}
		lassign $args newstate
		if {![string is integer -strict $newstate]} {
			switch -- $newstate {
				"soft_blocked" {set newstate 0}
				"unblocked" {set newstate 1}
				"hard_blocked" {set newstate 2}
				default {return -code error "unsupported state"}
			}
		}
		if {$newstate < 0 || $newstate > 2} {
			return -code error "unsupported state"
		} elseif {$st == 2} {
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

proc Main {args} {
	variable rfkill
	foreach d [glob -dir $rfkill(base) -- rfkill*] {
		if {[catch {type read $d} type]} {
			puts stderr "unsupported rfkill device at $d: $type"
			continue
		}
		if {[catch {state read $d} state]} {
			puts stderr "cannot read state of $type device: $state"
			continue
		}
		if {($rfkill($type,state) eq "keep") ||
			($rfkill($type,state) eq $state)} {
			puts "$type at [file tail $d] is $state"
			continue
		}
		if {[catch {state set $d $rfkill($type,state)} state]} {
			puts stderr "cannot set state of $type device: $state"
			continue
		}
		puts "$type at [file tail $d] was $state, now $rfkill($type,state)"
	}
}

Main {*}$::argv
