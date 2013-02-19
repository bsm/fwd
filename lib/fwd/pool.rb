# "Clone" of normal ConnectionPool but tweaked for round-robin
class Fwd::Pool
  include Enumerable

  class IdleStack < ConnectionPool::TimedStack
    def unshift(obj)
      @mutex.synchronize do
        @que.unshift obj
        @resource.broadcast
      end
    end
  end

  def initialize(items)
    @idle = IdleStack.new(0) {}
    @size = items.size
    @key  = :"io-proxy-pool-#{@idle.object_id}"

    items.each do |item|
      @idle.push(item)
    end
  end

  def each(&block)
    @size.times { checkout(&block) }
  end

  def checkout
    conn = @idle.pop(30)
    yield conn
  ensure
    @idle.unshift(conn) if conn
  end

end
