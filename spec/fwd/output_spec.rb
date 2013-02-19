require 'spec_helper'

describe Fwd::Output do

  let(:output) { described_class.new core }
  subject { output }

  class MockServer
    attr_reader :port, :data

    def initialize(port)
      @port   = port
      @data   = ""
      @server = ::TCPServer.new("127.0.0.1", port)
      @thread = Thread.new do
        loop do
          conn = @server.accept
          loop { @data << conn.readpartial(1024) }
        end
      end
      sleep(0.001) until @thread.alive?
    end

    def stop
      if @thread.alive?
        @thread.kill
        sleep(0.001) while @thread.alive?
      end

      unless @server.closed?
        @server.close
      end
    end
  end

  def servers(*ports)
    svs = ports.map {|port| MockServer.new(port) }
    yield(*svs)
    sleep(0.01)
    svs.each(&:stop)
    Hash[svs.map{|s| [s.port, s.data] }]
  end

  it 'should have a pool of backends' do
    subject.pool.should be_instance_of(Fwd::Pool)
    subject.pool.should have(2).items
    subject.pool.checkout {|c| c.should be_instance_of(Fwd::Backend) }
  end

  describe "writing" do

    it 'should forward data to backends' do
      servers(7291, 7292) do
        subject.write("A").should be(true)
        subject.write("B").should be(true)
        subject.write("C").should be(true)
        subject.write("D").should be(true)
      end.should == { 7291=>"BD", 7292=>"AC" }
    end

    it 'should handle partial fallouts' do
      servers(7291) do
        subject.write("A").should be(true)
        subject.write("B").should be(true)
        subject.write("C").should be(true)
        subject.write("D").should be(true)
      end.should == { 7291=>"ABCD" }
    end

    it 'should handle full fallouts' do
      subject.write("A").should be(false)
      subject.write("B").should be(false)
      subject.write("C").should be(false)
      subject.write("D").should be(false)
    end

  end

  describe "forwarding" do

    def write(file)
      file.open("w") {|f| f << "x" }
      file
    end

    def files(glob = "*")
      Dir[root.join(glob)].map {|f| File.basename f }.sort
    end

    before    { subject.stub! write: true }
    before    { FileUtils.mkdir_p root.to_s }
    let!(:f1) { write root.join("buffer.1.closed") }
    let!(:f2) { write root.join("buffer.2.open") }
    let!(:f3) { write root.join("buffer.3.closed") }

    it 'should write the data' do
      subject.should_receive(:write).twice
      subject.forward!
    end

    it 'should unlink written files' do
      lambda { subject.forward! }.should change {
        files
      }.to(["buffer.2.open"])
    end

    it 'should handle failures files' do
      subject.should_receive(:write).and_return(true)
      subject.should_receive(:write).and_return(false)

      lambda { subject.forward! }.should change {
        files
      }.to(["buffer.2.open", "buffer.3.closed"])
    end

  end
end