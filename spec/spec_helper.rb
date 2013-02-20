require 'bundler/setup'
require 'rspec'
require 'fwd'

module Fwd::TestHelper

  def with_em
    EM.run do
      begin
        yield
      ensure
        EM.stop
      end
    end
  end

  def root
    @_root ||= Pathname.new File.expand_path("../../tmp", __FILE__)
  end

  def core
    @_core ||= Fwd.new \
      path: root,
      flush_rate: 20,
      buffer_limit: 2048,
      forward: ["tcp://127.0.0.1:7291", "tcp://127.0.0.1:7292"]
  end

end

RSpec.configure do |c|
  c.include(Fwd::TestHelper)
  c.before(:suite) do
    Fwd.logger = Logger.new("/dev/null")
  end
  c.before(:each) do
    FileUtils.rm_rf root.to_s
  end
end