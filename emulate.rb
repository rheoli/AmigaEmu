#!/usr/bin/env ruby

$: << "./lib"

require 'amiga'

o=Amiga::Main.new
o.load_rom("roms/kick12.rom")
o.start

