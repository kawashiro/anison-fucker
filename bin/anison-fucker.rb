#!/usr/bin/env ruby
##
# Forces the song you wish for
#
# usage: anison-fucker
#           <song id>     Song ID, can be found in anison.fm song URL (https://anison.fm/song/<ID>/up)
#           [ --help ]    Show help message and exit
##

lib_dir = File.expand_path '../../lib', __FILE__
$:.insert 0, lib_dir if Dir.exist? lib_dir

require 'anison-fucker/application'


if $0 == __FILE__
  AnisonFucker::Application.new.run
end
