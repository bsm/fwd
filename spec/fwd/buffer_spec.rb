require 'spec_helper'

describe Fwd::Buffer do

  def files(glob = "*")
    Dir[root.join(glob)]
  end

  let(:buffer) { described_class.new core }
  subject      { buffer }

  its(:root)     { should == root }
  its(:prefix)   { should == "buffer" }
  its(:core)     { should be(core) }
  its(:count)    { should be(0) }
  its(:interval) { should be(60) }
  its(:rate)     { should be(20) }
  its(:limit)    { should be(2048) }
  its(:timer)    { should be(timer) }
  its(:fd)       { should be_nil }
  its(:logger)   { should be(core.logger) }

  describe "concat" do
    it 'should concat data' do
      subject.concat("x" * 1024)
      subject.fd.size.should == 1024
    end

    it 'should create the path' do
      lambda { buffer.concat("x") }.should change { buffer.root.exist? }.to(true)
    end

    it 'should rotate' do
      lambda { buffer.concat("x") }.should change { buffer.fd }.to(instance_of(File))
    end
  end

  describe "rotate" do
    before  { buffer.send(:rotate!) }
    subject { lambda { buffer.rotate! } }

    it 'should trigger when buffer limit is reached' do
      lambda { buffer.concat("x" * 2048) }.should_not change { buffer.fd.path }
      lambda { buffer.concat("x") }.should change { buffer.fd.path }
    end

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
      it { should_not change { buffer.fd.size }.from(0) }
      it { should_not change { files.size } }
    end
  end

  describe "flush" do

    before { core.stub flush!: true }

    it 'should trigger when flush rate is reached' do
      19.times { subject.concat("x") }
      lambda { subject.concat("x") }.should change { subject.count }.from(19).to(0)
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