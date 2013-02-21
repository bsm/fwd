class Fwd::Output
  extend Forwardable
  def_delegators :core, :logger, :root, :prefix

  CHUNK_SIZE = 16 * 1024
  RESCUABLE  = [
    Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::EPIPE,
    Errno::ENETUNREACH, Errno::ENETDOWN, Errno::EINVAL, Errno::ETIMEDOUT,
    IOError, EOFError
  ].freeze

  attr_reader :pool, :core

  # Constructor
  # @param [Fwd] core
  def initialize(core)
    backends = Array(core.opts[:forward]).compact.map do |s|
      Fwd::Backend.new(s)
    end
    @core = core
    @pool = Fwd::Pool.new(backends)
  end

  # Callback
  def forward!
    return if @forwarding

    @forwarding = true
    begin
      Dir[root.join("#{prefix}.*.closed")].sort.each do |file|
        ok = reserve(file) do |io|
          logger.debug { "Flushing #{File.basename(io.path)}, #{io.size.fdiv(1024).round} kB" }
          write(io)
        end
        ok or break
      end
    ensure
      @forwarding = false
    end
  end

  # @param [IO] io source stream
  def write(io)
    pool.any? do |backend|
      forward(backend, io)
    end
  end

  private

    def reserve(file)
      return if File.size(file) < 1

      target = Pathname.new(file.sub(/\.closed$/, ".reserved"))
      FileUtils.mv file, target.to_s

      result = false
      target.open("r") do |io|
        result = yield(io)
      end

      if result
        target.unlink
      else
        logger.error "Flushing of #{target} failed."
        FileUtils.mv target.to_s, target.to_s.sub(/\.reserved$/, ".closed")
      end

      result
    rescue Errno::ENOENT => e
      # Ignore if file was alread flushed by another process
      logger.warn "Flushing of #{File.basename(file)} postponed: #{e.message}"
    end

    def forward(backend, io)
      io.rewind
      until io.eof?
        backend.write(io.read(CHUNK_SIZE))
      end
      true
    rescue *RESCUABLE => e
      logger.error "Backend #{backend} failed: #{e.class.name} #{e.message}"
      backend.close
      false
    end

end