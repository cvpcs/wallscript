#!/usr/bin/tclsh

package require http
package require tdom

set config_url_sfw "http://konachan.net/post/random"
set config_url_nsfw "http://konachan.com/post/random"
set config_url "${config_url_sfw}"
set config_logsize 10

if {$argc < 3} {
	puts "Usage:"
	puts {     wallscript [nsfw] [backdrop_exec] [file]}
	puts {     wallscript [nsfw] [backdrop_exec] [file] [sleep]}
	exit
}

set config_nsfw          [lindex $argv 0]
set config_backdrop_exec [lindex $argv 1]
set config_file          [lindex $argv 2]
set config_time          [lindex $argv 3]
set config_oneshot       false

if {$argc < 4} {
	set config_oneshot true
}

if {$config_nsfw == "true"} {
	set config_url "${config_url_nsfw}"
}

proc get_redirect_url {} {
	global config_url

	dom parse -html [http::data [http::geturl "$config_url"]] doc
	set nodes [$doc selectNodes {//a}]
	if {[llength $nodes] != 1} {return ""}
	set redirect_url ""
	foreach node $nodes {set redirect_url [$node getAttribute href]}
	$doc delete

	return $redirect_url
}

proc get_img_url {redirect_url} {
	dom parse -html [http::data [http::geturl "$redirect_url"]] doc
	set nodes [$doc selectNodes {//img[@id='image']}]
	if {[llength $nodes] != 1} {return ""}
	set img_url ""
	foreach node $nodes {set img_url [$node getAttribute src]}
	$doc delete

	return $img_url
}

proc save_img {url file} {
	set data [http::data [http::geturl $url]]

	set fp [open "$file" "w"]
	fconfigure $fp -translation binary
	puts $fp $data
	flush $fp
	close $fp

	return "$file"
}

proc save_num {num file} {
	global config_logsize

	set num_list [list "[clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}] >>> $num"]

	if {[file exists "$file.log"]} {
		set ifp [open "$file.log" r]
		while {[gets $ifp line] >= 0} {
			lappend num_list $line
		}
		close $ifp
	}

	set ofp [open "$file.log" w]
	for {set i 0} {$i < [llength $num_list] && $i < $config_logsize} {incr i} {
		puts $ofp [lindex $num_list $i]
	}
	close $ofp
}

proc set_backdrop {file} {
	global config_backdrop_exec

	if {[file exists "$file"]} {
		set quoted [format "\"%s\"" [file nativename $file]]
		eval exec [format "${config_backdrop_exec}" "\"\""]
		eval exec [format "${config_backdrop_exec}" "${quoted}"]
	}
}

proc sleep {ms} {
	global sleep_val
	set sleep_val 0
	after $ms set sleep_val 1
	vwait sleep_val
}

proc main {} {
	global config_file
	global config_time
	global config_oneshot

	if {$config_oneshot} {
		set_backdrop $config_file
	} else {
		while {true} {
			set redirect_url ""
			set img_num 0
			set img_url ""
			set i 0

			if [catch {
				while {$img_url == "" && $i < 10} {
					set redirect_url [get_redirect_url]
					set img_url [get_img_url $redirect_url]
					incr i
				}

				if {$img_url != ""} {
					set img_num [regsub {^http://konachan.com/post/show/([0-9]+)/.*$} $redirect_url {\1}] 
					set_backdrop [save_img $img_url $config_file]
					save_num $img_num $config_file
				}

				if {$config_time <= 0} {
					break
				}
			} result] {
				puts stderr "Warning: $result"
			}

			sleep $config_time
		}
	}
}

main
