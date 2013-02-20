#!/usr/bin/env ruby

require 'pathname'
require 'benchmark'
require 'socket'
require 'fileutils'

root = Pathname.new(File.expand_path('../..', __FILE__))
tmp  = root.join("tmp/benchmark")
FileUtils.rm_rf tmp
FileUtils.mkdir_p tmp

OUT = tmp.join('out.txt')
FWD = fork { exec "#{root}/bin/fwd-rb --flush 10000:2 -F tcp://0.0.0.0:7291 --path #{tmp} -v" }
NCC = fork { exec "nc -vlp 7291 > #{OUT}" }

at_exit do
  Process.kill(:TERM, FWD)
  Process.kill(:TERM, NCC)
end

sleep(3)

EVENTS = 10_000_000
LENGTH = 100
DATA   = "A" * LENGTH

ds = Benchmark.realtime do
  sock = TCPSocket.new "127.0.0.1", 7289
  EVENTS.times { sock.write DATA }
  sock.close
end

rs = Benchmark.realtime do
  while OUT.size < EVENTS * LENGTH
    sleep(1)
    puts "--> Written       : #{(OUT.size / 1024.0 / 1024.0).round(1)}M of #{(EVENTS * LENGTH / 1024.0 / 1024.0).round(1)}M"
  end
end

sleep(3)
puts "--> Dispatched in : #{ds.round(1)}s"
puts "--> Completed in  : #{(ds + rs).round(1)}s"
puts "--> FWD RSS       : #{(`ps -o rss= -p #{FWD}`.to_f / 1024).round(1)}M"
puts "--> Processed     : #{EVENTS} events"
puts "--> Written       : #{(OUT.size / 1024.0 / 1024.0).round(1)}M"
