require 'pgversion'

module Transferatu
  class RunnerFactory
    def self.make_runner(transfer)
      from_version = PGVersion.parse(Sequel.connect(transfer.from_url) do |c|
                                       c.fetch("SELECT version()").get(:version)
                                     end)
      root = "/app/bin/pg/#{from_version.major_minor}"
      source = case transfer.from_url
               when /\Apostgres:/
                 PGDumpSource.new(transfer.from_url,
                                  opts: {
                                    no_owner: true,
                                    no_privileges: true,
                                    verbose: true,
                                    format: 'custom'
                                  },
                                  root: root,
                                  logger: transfer.method(:log))
               else
                 raise ArgumentError, "unkown source (supported: postgres)"
               end
      sink = case transfer.to_url
             when %r{\Ahttps://[^.]+\.s3.amazonaws.com}
               Gof3rSink.new(transfer.to_url, logger: transfer.method(:log))
             else
               raise ArgumentError, "unkown target (supported: s3)"
             end
      DataMover.new(source, sink)
    end
  end

  module ShellProcessLike
    # Takes a hash of snake-cased symbol keys and values that define
    # #to_s and builds an Array of command arguments with the
    # corresponding GNU flag representation. Returns the resulting
    # command as an array, ready to pass to Open3#popen or its kin.
    def command(cmd, opts, *args)
      result = if cmd.is_a? Array
                 cmd
               else
                 [ cmd ]
               end
      opts.each do |k,v|
        kstr = k.to_s
        if kstr.length == 1
          result << "-#{kstr}"
        else
          result << "--#{kstr.gsub(/_/, '-')}"
        end
        unless v == true
          result << v.to_s
        end
      end
      result + args
    end

    # Log line with owner's logger function
    def log(line, severity: :info)
      logger.call(line, severity: severity)
    end

    # Log each line to owner's logger function, the close the source
    def drain_log_lines(source)
      begin
        source.each_line { |l| log l.strip }
      ensure
        source.close
      end
    end
  end

  # A source that runs pg_dump
  class PGDumpSource
    include ShellProcessLike
    attr_reader :logger
    def initialize(url, opts: {}, logger:, root:)
      @url = url
      @env = { "LD_LIBRARY_PATH" =>  "#{root}/lib" }
      @cmd = command("#{root}/bin/pg_dump", opts, @url)
      @logger = logger
    end

    def cancel
      if @wthr
        Process.kill("INT", @wthr.pid)
      end
    rescue Errno::ESRCH
      # Do nothing; our async pg_dump may have completed. N.B.: this
      # means that right now, canceled transfers can in fact complete
      # successfully. This may be a bug or a feature. TBD.
    end

    def run_async
      log "Running #{@cmd.join(' ').sub(@url, 'postgres://...')}"
      stdin, @stdout, stderr, @wthr = Open3.popen3(@env, *@cmd)
      stdin.close
      @stderr_thr =  Thread.new { drain_log_lines(stderr) }
      @stdout
    end

    def wait
      log "waiting for pg_dump to complete"
      status = @wthr.value

      @stderr_thr.join
      @stdout.close

      log "pg_dump done; exited with #{status.exitstatus.inspect} (signal #{status.termsig.inspect})"
      # N.B.: we don't just return status.success? because it can be
      # nil when the process was signaled, and we want an unambiguous
      # answer here.
      status.success? == true
    end
  end

  # A Sink that uploads to S3
  class Gof3rSink
    include ShellProcessLike
    attr_reader :logger

    def initialize(url, opts: {}, logger:)
      # assumes https://bucket.as3.amazonaws.com/key/path URIs
      uri = URI.parse(url)
      hostname = uri.hostname
      bucket = hostname.split('.').shift
      key = uri.path.sub(/\A\//, '')
      # gof3r put -b $bucket -k $key; we assume the S3 keys are in the
      # environment.
      @cmd = command(%W(gof3r put), { b: bucket, k: key})
      @logger = logger
    end

    def cancel
      if @wthr
        Process.kill("INT", @wthr.pid)
      end
    rescue Errno::ESRCH
      # Do nothing; our async pg_dump may have completed. N.B.: this
      # means that right now, canceled transfers can in fact complete
      # successfully. This may be a bug or a feature. TBD.
    end

    def run_async
      log "Running #{@cmd.join(' ')}"
      stdin, stdout, stderr, @wthr = Open3.popen3(*@cmd)
      @stdout_thr = Thread.new { drain_log_lines(stdout) }
      @stderr_thr = Thread.new { drain_log_lines(stderr) }
      stdin
    end

    def wait
      log "waiting for upload to complete"
      # Process::Status object returned; return the actual exit status
      status = @wthr.value

      @stdout_thr.join
      @stderr_thr.join

      log "upload done; exited with #{status.exitstatus.inspect} (signal #{status.termsig.inspect})"
      # Same reasoning as PgDumpSource
      status.success? == true
    end

  end
end
