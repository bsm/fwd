class Fwd::Backend
  attr_reader :url

  def initialize(url)
    @url = URI(url)
  end

  def stream(file)
    IO.copy_stream file.to_s, sock
  end

  def close
    @sock.close if @sock
    @sock = nil
  end

  def to_s
    url.to_s
  end

  protected

    def sock
      @sock ||= TCPSocket.new @url.host, @url.port
    end

end
