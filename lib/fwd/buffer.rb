class Fwd::Buffer
  extend Forwardable
  def_delegators :core, :root, :prefix, :logger

  MAX_LIMIT = 64 * 1024 * 1024 # 64M
  attr_reader :core, :interval, :rate, :count, :limit, :timer, :fd

  # Constructor
  # @param [Fwd] core
  def initialize(core)
    @core     = core
    @interval = (core.opts[:flush_interval] || 60).to_i
    @rate     = (core.opts[:flush_rate] || 10_000).to_i
    @limit    = [core.opts[:buffer_limit].to_i, MAX_LIMIT].reject(&:zero?).min
    @count    = 0

    reschedule!
    rotate!
  end

  # @param [String] data binary data
  def concat(data)
    rotate! if rotate?
    @fd.write(data)
    @count += 1
    flush! if flush?
  end

  # (Force) flush buffer
  def flush!
    @count = 0
    rotate!
    core.flush!
  ensure
    reschedule!
  end

  # @return [Boolean] true if flush is due
  def flush?
    @rate > 0 && @count >= @rate
  end

  # (Force) rotate buffer file
  def rotate!
    return if @fd && @fd.size.zero?

    if @fd
      logger.debug { "Rotating #{File.basename(@fd.path)}, #{@fd.size / 1024} kB" }
      FileUtils.mv(@fd.path, @fd.path.sub(/\.open$/, ".closed"))
    end

    @fd = new_file
  rescue Errno::ENOENT
  end

  # @return [Boolean] true if rotation is due
  def rotate?
    @fd.nil? || @fd.size >= @limit
  rescue Errno::ENOENT
    false
  end

  private

    def new_file
      path = nil
      until path && !path.exist?
        path = root.join("#{generate_name}.open")
      end
      FileUtils.mkdir_p root.to_s
      file = path.open("wb")
      file.sync = true
      file
    end

    def reschedule!
      return unless @interval > 0

      @timer.cancel if @timer
      @timer = EM.add_periodic_timer(@interval) { flush! }
    end

    def generate_name
      [prefix, Time.now.utc.strftime("%Y%m%d%H%m%s"), SecureRandom.hex(4)].join(".")
    end

end