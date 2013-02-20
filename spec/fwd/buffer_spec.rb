require 'spec_helper'

describe Fwd::Buffer do

  def files(glob = "*")
    Dir[root.join(glob)]
  end

  let(:buffer) { described_class.new core }
  let(:timer)  { mock("Timer", cancel: true) }
  subject      { buffer }
  before do
    EM.stub add_periodic_timer: timer
  end

  its(:root)     { should == root }
  its(:root)     { should be_exist }
  its(:prefix)   { should == "buffer" }
  its(:core)     { should be(core) }
  its(:count)    { should be(0) }
  its(:interval) { should be(60) }
  its(:rate)     { should be(20) }
  its(:limit)    { should be(2048) }
  its(:timer)    { should be(timer) }
  its(:fd)       { should be_instance_of(File) }
  its(:logger)   { should be(Fwd.logger) }

  describe "concat" do
    it 'should concat data' do
      lambda {
        subject.concat("x" * 1024)
      }.should change {
        subject.fd.size
      }.by(1024)
    end
  end

  describe "rotate" do
    before  { buffer }
    subject { lambda { buffer.rotate! } }

    describe "when changed" do
      before { buffer.concat("x" * 1024) }

      it { should change { buffer.fd.path } }
      it { should change { files.size }.by(1) }

      it 'should archive previous file' do
        previous = buffer.fd.path
        subject.call
        files.should include(previous.sub("open", "closed").to_s)
      end
    end

    describe "when unchanged" do
      it { should_not change { buffer.fd.path } }
      it { should_not change { files.size } }
    end
  end

  describe "flush" do

    before { core.stub flush!: true }

    it 'should trigger when flush rate is reached' do
      19.times { subject.concat("x") }
      lambda { subject.concat("x") }.should change { subject.count }.from(19).to(0)
    end

    it 'should trigger when flush limit is reached' do
      subject.concat("x" * 1024)
      lambda { subject.concat("x" * 1024) }.should change { subject.count }.from(1).to(0)
    end

    it 'should reset count' do
      3.times { subject.concat("x") }
      lambda { subject.flush! }.should change { subject.count }.from(3).to(0)
    end

    it 'should rotate file' do
      subject.concat("x")
      lambda { subject.flush! }.should change { subject.fd.path }
      files.size.should == 2
    end

    it 'should reset timer' do
      subject.timer.should_receive(:cancel)
      subject.flush!
    end

    it 'should forward data' do
      3.times { subject.concat("x") }
      subject.core.should_receive(:flush!).and_return(true)
      subject.flush!
      sleep(0.1)
    end

  end
end