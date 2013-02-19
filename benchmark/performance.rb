#!/usr/bin/env ruby

$:.unshift(File.expand_path('../../lib', __FILE__))

require 'bundler/setup'
require 'benchmark'
require 'tempfile'
require 'fwd'

root = Pathname.new(File.expand_path('../..', __FILE__))
FileUtils.rm_rf root.join("tmp/benchmark")
FileUtils.mkdir_p root.join("tmp/benchmark")

EVENTS = 10_000_000
DATA   = "A" * 64
OUTF   = root.join('tmp/benchmark/out.txt')

COLL   = fork do
  `nc -vlp 7291 > #{OUTF}`
  sleep
end
EMIT   = fork do
  sock = TCPSocket.new "127.0.0.1", 7289
  EVENTS.times { sock.write DATA }
  sock.close
end

at_exit do
  Process.kill(:TERM, COLL)
  Process.kill(:TERM, EMIT)
end

until OUTF.exist?
  sleep(1)
end

while OUTF.size < EVENTS * DATA.size
  sleep(1)
  puts "Written #{(OUTF.size / 1024.0 / 1024.0).round(1)}M"
end
