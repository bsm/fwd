require 'spec_helper'

describe Fwd do

  subject      { core }

  its(:logger) { should be_instance_of(::Logger) }
  its(:root)   { should be_instance_of(::Pathname) }
  its(:root)   { should == root }
  its(:bind)   { should be_instance_of(URI::Generic) }
  its(:bind)   { should == URI("tcp://0.0.0.0:7289") }
  its(:prefix) { should == "buffer" }
  its(:opts)   { should be_instance_of(Hash) }
  its(:logger) { should be_instance_of(Logger) }
  its(:output) { should be_instance_of(Fwd::Output) }

  it "should listen the server" do
    with_em do
      subject.logger.should_receive(:info)
      subject.listen!.should be_instance_of(Fixnum)
    end
  end

end