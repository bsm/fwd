require 'spec_helper'

describe Fwd::Backend do

  subject do
    described_class.new "tcp://127.0.0.1:7289"
  end

  before do
    TCPSocket.any_instance.stub write: true
  end

  its(:url)  { should be_instance_of(URI::Generic) }
  its(:to_s) { should == "tcp://127.0.0.1:7289" }

end