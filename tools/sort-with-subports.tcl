#!/usr/bin/env port-tclsh
#
# Generates a list of ports where a port is only listed after all of its
# dependencies (sans variants) have already been listed. Includes all
# sub-ports of the specified ports.
#
# Copyright (c) 2006,2008 Bryan L Blackburn.  All rights reserved.
# Copyright (c) 2018 The MacPorts Project
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
# 3. Neither the name Bryan L Blackburn, nor the names of any contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS''
# AND ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

package require macports


proc ui_prefix {priority} {
   return "OUT: "
}


proc ui_channels {priority} {
   return {}
}


proc process_port_deps {portname portdeps_in portlist_in} {
    upvar $portdeps_in portdeps
    upvar $portlist_in portlist
    set deplist $portdeps($portname)
    unset portdeps($portname)
    foreach portdep $deplist {
        if {[info exists portdeps($portdep)]} {
            process_port_deps $portdep portdeps portlist
        }
    }
    lappend portlist $portname
}


if {[catch {mportinit "" "" ""} result]} {
   puts stderr "$errorInfo"
   error "Failed to initialize ports system: $result"
}

array set portdepinfo {}
array set canonicalnames {}
set todo [list]
if {[lindex $argv 0] eq "-"} {
    while {[gets stdin line] >= 0} {
        lappend todo [string tolower [string trim $line]]
    }
} else {
    foreach p $argv {
        lappend todo [string tolower $p]
    }
}
# save the ones that the user actually wants to know about
foreach p $todo {
    set inputports($p) 1
    set outputports($p) 1
}
# process all recursive deps
set depstypes {depends_fetch depends_extract depends_patch depends_build depends_lib depends_run}
while {$todo ne {}} {
    set p [lindex $todo 0]
    set todo [lrange $todo 1 end]
    if {[catch {mportlookup $p} result]} {
        puts stderr "$errorInfo"
        error "Failed to find port '$p': $result"
    }
    if {[llength $result] < 2} {
        puts stderr "port $p not found in the index"
        continue
    }

    array set portinfo [lindex $result 1]
    if {![info exists portdepinfo($p)]} {
        if {[info exists inputports($p)] && [info exists portinfo(subports)]} {
            foreach subport $portinfo(subports) {
                set splower [string tolower $subport]
                if {![info exists portdepinfo($splower)]} {
                    lappend todo $splower
                }
                set outputports($splower) 1
            }
        }
        set deplist [list]
        foreach depstype $depstypes {
            if {[info exists portinfo($depstype)] && $portinfo($depstype) ne ""} {
                foreach onedep $portinfo($depstype) {
                    set depname [string tolower [lindex [split [lindex $onedep 0] :] end]]
                    lappend deplist $depname
                    lappend todo $depname
                }
            }
        }
        set portdepinfo($p) $deplist
        if {[info exists outputports($p)]} {
            set canonicalnames($p) $portinfo(name)
        }
    }
    array unset portinfo
}

set portlist [list]
foreach portname [lsort -dictionary [array names portdepinfo]] {
   if {[info exists portdepinfo($portname)]} {
      process_port_deps $portname portdepinfo portlist
   }
}

foreach portname $portlist {
    if {[info exists outputports($portname)]} {
        puts $canonicalnames($portname)
    }
}
