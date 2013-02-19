require 'spec_helper'

describe Fwd::Input do

  subject do
    input = described_class.allocate
    input.send(:initialize, core)
    input
  end
  before { EM.stub :add_periodic_timer }

  it { should be_a(EM::Connection) }
  its(:buffer) { should be_nil }
  its(:logger) { should be(Fwd.logger) }

  describe "post init" do
    before { subject.post_init }
    its(:buffer) { should be_instance_of(Fwd::Buffer) }
  end

end