require 'spec_helper'

describe Fwd::CLI do

  subject do
    described_class.new [
      "--path", root.to_s,
      "--prefix", "prefix",
      "--bind", "tcp://127.0.0.1:7289",
      "--forward", "tcp://1.2.3.4:1234,tcp://1.2.3.5:1235",
      "--flush", "1200:90",
      "--log", "/dev/null",
      "--verbose",
    ]
  end

  it { should be_a(Hash) }
  its([:path]) { should == root.to_s }
  its([:prefix]) { should == "prefix" }
  its([:bind]) { should == "tcp://127.0.0.1:7289" }
  its([:forward]) { should == ["tcp://1.2.3.4:1234", "tcp://1.2.3.5:1235"] }
  its([:flush_rate]) { should == 1200 }
  its([:flush_interval]) { should == 90 }
  its([:log]) { should == "/dev/null" }
  its([:log_level]) { should == 0 }
  its(:core) { should be_instance_of(Fwd) }

end