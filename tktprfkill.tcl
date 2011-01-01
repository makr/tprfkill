#!/usr/bin/env wish8.5
# --------------------------------------------------------------------------
#
# Copyright © 2011 Matthias Kraft <M.Kraft@gmx.com>.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# --------------------------------------------------------------------------

package require Tk 8.5

namespace eval tktprfkill {
    variable _Dir [file dirname [info script]]
    source [file join $_Dir tprfkill.tcl]

    variable WindowTitle "ThinkPad RF Kill Switch"
    variable RootWindow  "."
}

proc tktprfkill::Main {args} {
    variable WindowTitle
    variable RootWindow
    variable Wait4Exit

    if {$RootWindow eq "."} {
	set _Base ""
	wm withdraw .
	wm title . $WindowTitle
    } else {
	set _Base $RootWindow
    }
    if {[catch {
	# Create the UI
	MakeUI $RootWindow $_Base
    } err]} {
	tk_messageBox -message "Unable to create graphical user interface, exiting!" \
	    -detail $err -icon error -title "Error when creating the GUI ..." \
	    -type ok
	return 1
    }

    # enter event loop
    tkwait variable [namespace which -variable Wait4Exit]
    return $Wait4Exit
}

# 1st layer arrangements
proc tktprfkill::MakeUI {root base} {
    set menu [MakeMenu $base]
    set stat [MakeStatus $base]
    set ctrl [MakeCtrl $base]

    grid $stat -in $root -row 1 -column 1 \
	-columnspan 1 \
	-ipadx 0 \
	-ipady 0 \
	-padx 0 \
	-pady 0 \
	-rowspan 1 \
	-sticky "news"
    grid $ctrl -in $root -row 2 -column 1 \
	-columnspan 1 \
	-ipadx 0 \
	-ipady 0 \
	-padx 0 \
	-pady 0 \
	-rowspan 1 \
	-sticky "news"

    grid rowconfigure $root 1 -weight 0 -minsize 40 -pad 0
    grid rowconfigure $root 2 -weight 0 -minsize 40 -pad 0
    grid columnconfigure $root 1 -weight 0 -minsize 40 -pad 0

    $root configure -menu $menu

    if {$root eq "."} {
	wm protocol . WM_DELETE_WINDOW [namespace code Quit]
	wm deiconify .
    }
}

# 2nd layer: menu
proc tktprfkill::MakeMenu {base} {
    variable menu
    variable sub1
    variable sub2

    set menu [menu $base.menu]

    # Menu: File
    set sub1 [menu $base.sub1 -tearoff 0]
    $base.menu add cascade \
	-accelerator "F" \
	-label "File" \
	-menu $base.sub1
    $base.sub1 add command \
	-accelerator "R" \
	-label "(Re)Read" \
	-command [namespace code [list HandleOP read]]
    $base.sub1 add command \
	-accelerator "S" \
	-label "Save" \
	-command [namespace code [list HandleOP save]]
    $base.sub1 add separator
    $base.sub1 add command \
	-accelerator "Q" \
	-label "Quit" \
	-command [namespace code Quit]

    # Menu: Help
    set sub2 [menu $base.sub2 -tearoff 0]
    $base.menu add cascade \
	-accelerator "H" \
	-label "Help" \
	-menu $base.sub2
    $base.sub2 add command \
	-accelerator "A" \
	-label "About" \
	-command [namespace code AboutDialog]

    return $menu
}

# 2nd layer: status frame
proc tktprfkill::MakeStatus {base} {
    variable status

    set status(frame) [labelframe $base.lf -text "Status"]

    # TODO: Make dynamic, according to available devices
    set status(label,name,dev) [label $base.lf.ln1 -text "<Device>:"]
    set status(label,stat,dev) [label $base.lf.ls1 -text "<Status>"]
    grid $status(label,name,dev) -in $status(frame) -row 1 -column 1 \
	-columnspan 1 \
	-ipadx 0 \
	-ipady 0 \
	-padx 0 \
	-pady 0 \
	-rowspan 1 \
	-sticky "e"
    grid $status(label,stat,dev) -in $status(frame) -row 1 -column 2 \
	-columnspan 1 \
	-ipadx 0 \
	-ipady 0 \
	-padx 0 \
	-pady 0 \
	-rowspan 1 \
	-sticky "w"

    grid rowconfigure $base.lf 1 -weight 0 -minsize 40 -pad 0
    grid columnconfigure $base.lf 1 -weight 0 -minsize 40 -pad 0
    grid columnconfigure $base.lf 2 -weight 0 -minsize 40 -pad 0

    return $status(frame)
}

# 2nd: control frame
proc tktprfkill::MakeCtrl {base} {
    variable control

    set control(frame) [labelframe $base.cf -text "Control"]

    # TODO: Make dynamic, according to available devices
    set control(btn,name,dev) [checkbutton $base.cf.cb1 -text "<Device>" \
	-state normal \
	-command [namespace code [list CtrlDev dev]]]
    grid $control(btn,name,dev) -in $control(frame) -row 1 -column 1 \
	-columnspan 1 \
	-ipadx 0 \
	-ipady 0 \
	-padx 0 \
	-pady 0 \
	-rowspan 1 \
	-sticky ""

    grid rowconfigure $base.cf 1 -weight 0 -minsize 40 -pad 0
    grid columnconfigure $base.cf 1 -weight 0 -minsize 40 -pad 0

    return $control(frame)
}

# bridging GUI and functionality
proc tktprfkill::HandleOP {op args} {
    TODO not implemented
}

proc tktprfkill::Quit {{cancelled 0}} {
    variable Wait4Exit

    set Wait4Exit $cancelled
}

proc tktprfkill::AboutDialog {} {
    tk_messageBox -message "ThinkPad RF Kill Switch 1.0" \
	-detail "Copyright © 2011 Matthias Kraft <M.Kraft@gmx.com>." \
	-title "About tktprfkill ..." -type ok -icon info
}

# TODO: unblocked: normal,on; soft_blocked: normal,off; hard_blocked; disabled,off
proc tktprfkill::CtrlDev {dev} {
    TODO not implemented
}

if {![info exists ::tcl_interactive] || !$::tcl_interactive} {
    # start program automatically only if not sourced in a wish
    exit [tktprfkill::Main {*}$::argv]
}
