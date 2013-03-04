#!/usr/bin/env ruby

require 'yaml'
require 'json'

a=YAML.load(File.open("m68k.yaml"))

File.open("m68k.json","wt") do |f|
  f.puts a.to_json
end
