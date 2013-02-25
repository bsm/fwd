require 'spec_helper'

describe Fwd::Input do

  let(:buffer) { Fwd::Buffer.new(core) }
  subject do
    input = described_class.allocate
    input.send(:initialize, core, buffer)
    input
  end

  before { EM.stub :add_periodic_timer }

  it { should be_a(EM::Connection) }
  its(:core) { should be(core) }
  its(:buffer) { should be(buffer) }
  its(:logger) { should be(core.logger) }

end