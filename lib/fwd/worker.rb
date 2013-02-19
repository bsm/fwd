class Fwd::Worker

  class << self
    private :new

    def fork(opts)
      GC.copy_on_write_friendly = true if GC.respond_to?(:copy_on_write_friendly=)

      child_read, parent_write = IO.pipe
      parent_read, child_write = IO.pipe

      pid = Process.fork do
        begin
          parent_write.close
          parent_read.close
          output = Fwd::Output.new(opts)
          process(output, child_read, child_write)
        ensure
          child_read.close
          child_write.close
        end
      end

      child_read.close
      child_write.close

      new(pid, parent_read, parent_write)
    end

    def process(output, read, write)
      while !read.eof?
        path = Marshal.load(read)
        begin
          result = call_with_index(items, index, options, &block)
          result = nil if options[:preserve_results] == false
        rescue Exception => e
          result = ExceptionWrapper.new(e)
        end
        Marshal.dump(result, write)
      end
    end

  end