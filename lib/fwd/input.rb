class Fwd::Input < EM::Connection
  extend Forwardable
  def_delegators :core, :logger

  attr_reader :core, :buffer

  # @param [Fwd] core
  # @param [Hash] opts additional opts
  def initialize(core)
    @core = core
  end

  def post_init
    @buffer = Fwd::Buffer.new(core)
  end

  # When receiving data, concat it to the buffer
  def receive_data(data)
    buffer.concat(data)
  end

end