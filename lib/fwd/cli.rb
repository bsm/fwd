require 'optparse'
require 'fwd'

class Fwd::CLI < Hash

  def self.run!(argv = ARGV)
    new(argv).run!
  end

  attr_reader :core

  def initialize(argv)
    super()
    parser.parse!(argv)
    @core = Fwd.new(self)
  end

  def run!
    @core.run!
  end

  def parser
    @parser ||= OptionParser.new do |o|
      o.banner = "Usage: fwd-rb [options]"
      o.separator ""

      o.on("-B", "--bind URI", "Listen on this address. Default: tcp://0.0.0.0:7289") do |uri|
        update bind: URI.parse(uri).to_s
      end

      o.on("-F", "--forward U1,[..,Un]", Array, "Forward to these URIs") do |uris|
        update forward: uris.map {|uri| URI.parse(uri).to_s }
      end

      o.on("-f", "--flush M:N",
        "Flush after an interval of N seconds, " <<
        "or after receiving M messages, " <<
        "Default: 10000:60") do |values|
        m,n = values.split(":").map(&:to_i)
        update flush_rate: m.to_i, flush_interval: n.to_i
      end

      o.on("--path PATH", "Root path for storage. Default: ./tmp") do |path|
        update path: path
      end

      o.on("--prefix STRING", "Custom prefix for buffer files. Default: buffer") do |prefix|
        update prefix: prefix
      end

      o.on("-v", "--verbose", "Enable verbose logging.") do |_|
        Fwd.logger.level = Logger::DEBUG
      end

      o.separator ""
      o.on_tail("-h", "--help", "Show this message") do
        puts o
        exit
      end
    end
  end

end