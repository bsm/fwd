class Fwd::Input < EM::Connection
  extend Forwardable
  def_delegators :core, :logger

  attr_reader :core, :buffer

  # @param [Fwd] core
  # @param [Fwd::Buffer] buffer
  def initialize(core, buffer)
    @core   = core
    @buffer = buffer
  end

  # When receiving data, concat it to the buffer
  def receive_data(data)
    buffer.concat(data)
  end

end