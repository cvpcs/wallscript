#!/usr/bin/tclsh

package require http
package require tdom

set config_url "http://konachan.com/post/show/"

if {$argc < 3} {
	puts "Usage:"
	puts {     wallscript_save [file] [dir] [prefix]}
	exit
}

set config_file [lindex $argv 0]
set config_dir [lindex $argv 1]
set config_prefix [lindex $argv 2]

proc get_img_url {num} {
	global config_url
	dom parse -html [http::data [http::geturl "$config_url$num"]] doc
	set nodes [$doc selectNodes {//img[@id]}]
	if {[llength $nodes] != 1} {return ""}
	set img ""
	foreach node $nodes {set img [$node getAttribute src]}
	$doc delete
	return $img
}

proc save_img {url file} {
	set data [http::data [http::geturl $url]]

	set fp [open "$file" w+]
	puts $fp $data
	close $fp

	return "$file"
}

proc main {} {
	global config_file
	global config_dir
	global config_prefix

	if {[file exists "$config_file"]} {
		set ifp [open "$config_file" r]
		while {[gets $ifp line] >= 0} {
			regsub {^(.*[^0-9])?([0-9]+)$} $line {\2} num
			set url [get_img_url $num]
			if {$url != ""} {
				regsub {^.*(\.[^.]+)$} $url {\1} ext
				if {$url == $ext} {set ext ""}
				save_img $url "$config_dir/$config_prefix$num$ext"
			}
		}
		close $ifp
	}
}

main
