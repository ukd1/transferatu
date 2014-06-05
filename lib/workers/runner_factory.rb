module Transferatu
  class RunnerFactory
    
  end

  # 
  class PGDumpSource
    def initialize(url, opts, logger=nil)
      @url = url
      @opts = opts
      @logger = logger
    end

    def log(line)
      @logger.call(line) if @logger
    end

    def cancel
      if @whtr
        Process.kill("INT", @wthr.pid)
      end
    rescue Errno::ESRCH
      # do nothing; our async pg_dump may have completed
    end

    def run_async
      
    end

    def wait
      
    end
  end

  # A Sink that uploads to S3
  class Gof3rSink

  end

end
