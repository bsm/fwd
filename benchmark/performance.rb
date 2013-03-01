#!/usr/bin/env ruby

require 'pathname'
require 'benchmark'
require 'socket'
require 'fileutils'

root = Pathname.new(File.expand_path('../..', __FILE__))
TMP  = root.join("tmp/benchmark")
OUT  = TMP.join('out.txt')

FileUtils.rm_rf TMP
FileUtils.mkdir_p TMP
FileUtils.touch(OUT)

FWD = fork { exec "#{root}/bin/fwd-rb --flush 10000:2 -F tcp://0.0.0.0:7291 --path #{TMP} -v" }
NCC = fork { exec "nc -kl 7291 > #{OUT}" }

sleep(5)

EVENTS = 10_000_000
DATA   = (("A".."Z").to_a + ("a".."z").to_a).join + "\n"
LENGTH = DATA.size
CCUR   = 5

ds   = Benchmark.realtime do
  (1..CCUR).map do
    fork do
      sock = TCPSocket.new "127.0.0.1", 7289
      (EVENTS / CCUR).times { sock.write DATA }
      sock.close
    end
  end.each {|t| Process.wait(t) }
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

Process.kill(:TERM, FWD)
Process.kill(:TERM, NCC)
