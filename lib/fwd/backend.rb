class Fwd::Backend
  attr_reader :url

  CHUNK_SIZE = 16 * 1024

  def initialize(url)
    @url = URI(url)
  end

  def stream(file)
    File.open(file.to_s, "rb", encoding: Encoding::BINARY) do |io|
      sock.write(io.read(CHUNK_SIZE)) until io.eof?
    end
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
