class Fwd::Output
  extend Forwardable
  def_delegators :core, :logger, :root, :prefix

  RESCUABLE = [
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
    Dir[root.join("#{prefix}.*.closed")].each do |file|
      ok = reserve(file) do |data|
        logger.debug { "Flushing #{File.basename(file)}, #{data.size.fdiv(1024).round} kB" }
        write(data)
      end
      break unless ok
    end
  end

  # @param [String] binary data
  def write(data)
    pool.any? do |backend|
      forward(backend, data)
    end
  end

  private

    def reserve(file)
      return if File.size(file) < 1

      target = Pathname.new(file.sub(/\.closed$/, ".reserved"))
      FileUtils.mv file, target.to_s

      result = yield(target.read)
      if result
        target.unlink
      else
        logger.error "Flushing of #{target} failed."
        FileUtils.mv target.to_s, target.to_s.sub(/\.reserved$/, ".closed")
      end

      result
    rescue Errno::ENOENT
      # Ignore if file was alread flushed by another process
    end

    def forward(backend, data)
      backend.write(data) && true
    rescue *RESCUABLE => e
      logger.error "Backend #{backend} failed: #{e.class.name} #{e.message}"
      backend.close
      false
    end

end