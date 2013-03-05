require 'eventmachine-le'
require 'forwardable'
require 'uri'
require 'logger'
require 'fileutils'
require 'pathname'
require 'securerandom'
require 'connection_pool'
require 'servolux'
require 'io/splice'

class Fwd
  FLUSH = "\000>>"

  # @attr_reader [URI] uri to bind to
  attr_reader :bind

  # @attr_reader [Pathname] root path
  attr_reader :root

  # @attr_reader [String] custom buffer file prefix
  attr_reader :prefix

  # @attr_reader [Fwd::Output] output
  attr_reader :output

  # @attr_reader [Logger] logger
  attr_reader :logger

  # @attr_reader [Hash] opts
  attr_reader :opts

  # Constructor
  # @param [Hash] opts
  # @option opts [String]  path path where buffer files are stored
  # @option opts [String]  prefix buffer file prefix
  # @option opts [URI] bind the endpoint to listen to
  # @option opts [Array<URI>] forward the endpoints to forward to
  # @option opts [Integer] buffer_limit limit buffer files to N bytes
  # @option opts [Integer] flush_rate flush after N messages
  # @option opts [Integer] flush_interval flush after N seconds
  def initialize(opts = {})
    @opts   = opts
    @bind   = URI.parse(opts[:bind] || "tcp://0.0.0.0:7289")
    @root   = Pathname.new(opts[:path] || "tmp")
    @prefix = opts[:prefix] || "buffer"
    @logger = ::Logger.new(opts[:log] || STDOUT)
    @logger.level = opts[:log_level] || ::Logger::INFO
    @output = Fwd::Output.new(self)
  end

  # Starts the loop
  def run!
    @piper = ::Servolux::Piper.new('rw')

    at_exit do
      @piper.signal("TERM")
    end

    @piper.child do
      $0 = "fwd-rb (input)"
      EM.run { listen! }
    end

    @piper.parent do
      $0 = "fwd-rb (output)"
      output_loop!
    end
  end

  # Starts the server
  def listen!
    logger.info "Starting server on #{@bind}"
    buffer = Fwd::Buffer.new(self)
    EM.start_server @bind.host, @bind.port, Fwd::Input, self, buffer
  end

  # Starts the output loop
  def output_loop!
    loop do
      sleep(0.1)
      case val = @piper.gets()
      when FLUSH
        @output.forward!
      else
        logger.error "Received unknown message #{val.class.name}: #{val.inspect}"
        exit
      end
    end
  end

  # Initiates flush
  def flush!
    @piper.child do
      @piper.puts(FLUSH)
    end
  end

end

%w|buffer output backend input pool cli|.each do |name|
  require "fwd/#{name}"
end
