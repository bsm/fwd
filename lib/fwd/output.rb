class Fwd::Output
  extend Forwardable
  def_delegators :core, :logger, :root, :prefix

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
      ok = reserve(file) do |reserved|
        start   = Time.now
        success = stream_file(reserved)
        real    = Time.now - start
        logger.info { "Flushed #{reserved.basename}, #{reserved.size.fdiv(1024).round}k in #{real.round(1)}s (Q: #{q.size})" }
        success
      end
      ok || break
    end
  ensure
    @forwarding = false
  end

  # @param [Pathname] file file to stream
  def stream_file(file)
    pool.any? do |backend|
      stream_to(backend, file)
    end
  end

  private

    def reserve(file)
      return if File.size(file) < 1

      target = Pathname.new(file.sub(/\.closed$/, ".reserved"))
      FileUtils.mv file, target.to_s

      success = yield(target)
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

    def stream_to(backend, file)
      backend.stream(file)
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