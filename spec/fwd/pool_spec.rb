require 'spec_helper'

describe Fwd::Pool do

  subject do
    described_class.new ["A", "B", "C"]
  end

  it { should be_a(Enumerable) }
  its(:to_a) { should == ["C", "B", "A"] }

  it "should round-robin" do
    subject.checkout {|c| c.should == "C" }
    subject.checkout {|c| c.should == "B" }
    subject.checkout {|c| c.should == "A" }
    subject.checkout {|c| c.should == "C" }
    subject.checkout {|c| c.should == "B" }
    subject.checkout {|c| c.should == "A" }
  end

end

