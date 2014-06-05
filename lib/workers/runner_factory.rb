module Transferatu
  class RunnerFactory
    def make_runner(transfer)
      unless transfer.from_url =~ /\Apostgres:/ && transfer.to_url =~ /\As3:/
        raise ArgumentError, "only postgres backups to s3 currently supported"
      end
      source = PGDumpSource.new(transfer.from_url,
                                opts: {
                                  no_owner: true,
                                  no_privileges: true,
                                  verbose: true,
                                  format: 'custom'
                                },
                                logger: transfer.logger)
      sink = Gof3rSink.new(transfer.to_url, logger: transfer.logger)
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
          "--#{kstr.gsub(/_/, '-')}"
        end
        unless v == true
          result << v
        end
      end
      result + args
    end

    # Log line with owner's logger function
    def log(line, level: :info)
      # TODO: make the distinction between internal and user-visible
      # logs here
      logger.call(line)
    end

    # Log each line to owner's logger function, the close the source
    def drain_log_lines(source)
      begin
        source.each_line { |l| log l }
      ensure
        source.close
      end
    end
  end

  # A source that runs pg_dump
  class PGDumpSource
    include ShellProcessLike
    attr_reader :logger
    def initialize(url, opts: {}, logger:)
      @url = url
      # TODO: only take whitelisted opts
      @cmd = command('pg_dump', opts, @url)
      @logger = logger
    end

    def cancel
      if @whtr
        Process.kill("INT", @wthr.pid)
      end
    rescue Errno::ESRCH
      # Do nothing; our async pg_dump may have completed. N.B.: this
      # means that right now, canceled transfers can in fact complete
      # successfully. This may be a bug or a feature. TBD.
    end

    def run_async
      log "Running #{@cmd.join(' ').sub(@url, 'postgres://...')}"
      stdin, @stdout, stderr, @wthr = Open3.popen3(*@cmd)
      stdin.close
      @stderr_thr =  Thread.new { drain_log_lines(stderr) }
    rescue StandardError => e
      log "pg_dump failed: #{e.inspect}"
      raise
    end

    def wait
      log "waiting for pg_dump to complete"
      status = @wthr.value

      @stderr_thr.join
      @stdout.close

      log "pg_dump done; exited with #{status.exitstatus} (signal #{status.termsig})"
      # N.B.: we don't just return status.success? because it can be
      # nil when the process was signaled, and we want an unambiguous
      # answer here.
      status.success? == true
    end
  end

  # A Sink that uploads to S3
  class Gof3rSink
    include ShellProcessLike
    def initialize(url, opts: {}, logger:)
      # assumes http S3 URIs
      uri = URI.parse(url)
      segments = uri.path.split('/')
      bucket, key = segments[1], segments[2]
      # gof3r put -b $bucket -k $key; we assume the S3 keys are in the
      # environment.
      @cmd = command(%W(gof3r put), { b: bucket, k: key})
      @logger = logger
    end

    def cancel
      if @whtr
        Process.kill("INT", @wthr.pid)
      end
    rescue Errno::ESRCH
      # Do nothing; our async pg_dump may have completed. N.B.: this
      # means that right now, canceled transfers can in fact complete
      # successfully. This may be a bug or a feature. TBD.
    end

    def run_async
      log "Running #{@cmd.join(' ')}"
      stdin, stdout, stderr, @wthr = Open3.popen3(*cmd)
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

    log "upload done; exited with #{status.exitstatus} (signal #{status.termsig})"
    # Same reasoning as PgDumpSource
    status.success? == true
  end

  end
end
