class Fwd::Backend
  attr_reader :url

  CHUNK_SIZE = 16 * 1024

  def initialize(url)
    @url = URI(url)
  end

  def stream(file)
    sock = TCPSocket.new @url.host, @url.port
    begin
      File.open(file.to_s, "rb", encoding: Encoding::BINARY) do |io|
        sock.write(io.read(CHUNK_SIZE)) until io.eof?
      end
    ensure
      sock.close
    end
  end

  def to_s
    url.to_s
  end

end
