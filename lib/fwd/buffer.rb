class Fwd::Buffer
  extend Forwardable
  def_delegators :core, :root, :prefix, :logger

  MAX_SIZE = 64 * 1024 * 1024 # 64M
  attr_reader :core, :interval, :rate, :count, :limit, :timer, :fd, :path

  # Constructor
  # @param [Fwd] core
  def initialize(core)
    @core     = core
    @interval = (core.opts[:flush_interval] || 60).to_i
    @rate     = (core.opts[:flush_rate] || 10_000).to_i
    @limit    = (core.opts[:flush_limit] || 0).to_i
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
    (@rate > 0 && @count >= @rate) || (@limit > 0 && @path.size >= @limit)
  end

  # (Force) rotate buffer file
  def rotate!
    FileUtils.mv(@path.to_s, @path.to_s.sub(/\.open$/, ".closed")) if @path
    @fd, @path = new_file
  rescue Errno::ENOENT
  end

  # @return [Boolean] true if rotation is due
  def rotate?
    !@fd || @path.size > MAX_SIZE
  end

  private

    def new_file
      path = nil
      until path && !path.exist?
        path = root.join("#{generate_name}.open")
      end
      FileUtils.mkdir_p root.to_s
      file = File.open(path, "wb")
      file.sync = true
      [file, path]
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