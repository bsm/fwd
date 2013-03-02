class Fwd::Output
  extend Forwardable
  def_delegators :core, :logger, :root, :prefix

  CHUNK_SIZE = 1024 * 1024
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
    while (q = closed_files) && (file = q.shift)
      ok = reserve(file) do |io|
        start   = Time.now
        success = send_data(io)
        real    = Time.now - start
        logger.info { "Flushed #{File.basename(io.path)}, #{io.size.fdiv(1024).round}k in #{real.round(1)}s (Q: #{q.size})" }
        success
      end
      ok || break
    end
  ensure
    @forwarding = false
  end

  # @param [IO] io source stream
  def send_data(io)
    pool.any? do |backend|
      send_to(backend, io)
    end
  end

  private

    def reserve(file)
      return if File.size(file) < 1

      target = Pathname.new(file.sub(/\.closed$/, ".reserved"))
      FileUtils.mv file, target.to_s

      success = false
      target.open("r") do |io|
        success = yield(io)
      end

      if success
        target.unlink
      else
        logger.error "Flushing #{File.basename(file)} failed"
        FileUtils.mv target.to_s, file
      end

      success
    rescue Errno::ENOENT => e
      # Ignore if file was alread flushed by another process
      logger.warn "Flushing #{File.basename(file)} postponed: #{e.message}"
    end

    def send_to(backend, io)
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

    def closed_files
      Dir[root.join("#{prefix}.*.closed")].sort
    end

end