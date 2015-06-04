require 'open3'
require 'pgversion'

module Transferatu
  class RunnerFactory
    def self.runner_for(transfer)
      from_type, to_type = transfer.from_type, transfer.to_type

      if from_type == 'gof3r' && to_type == 'gof3r'
        raise ArgumentError, "S3 transfers not supported"
      end

      to_version = nil
      logger = ThreadSafeLogger.new(transfer).method(:log)
      sink = case to_type
             when 'pg_restore'
               to_version = PGVersion.parse(Sequel.connect(transfer.to_url) do |c|
                                              c.fetch("SELECT version()").get(:version)
                                            end)
               pg_root = "/app/bin/pg/#{to_version.major_minor}"
               PGRestoreSink.new(transfer.to_url,
                                 opts: {
                                   no_owner: true,
                                   no_privileges: true,
                                   verbose: true,
                                   format: 'custom'
                                 },
                                 root: pg_root,
                                 logger: logger)
             when 'gof3r'
               Gof3rSink.new(transfer.to_url, logger: logger)
             else
               raise ArgumentError, "Unkown transfer sink type: #{to_type}"
             end

      source = case from_type
               when 'pg_dump'
                 # N.B.: if the pg_root has already been set, only
                 # override it if the source is of a higher version.
                 # This can be useful for upgrades and is necessary
                 # for downgrades.
                 from_version = PGVersion.parse(Sequel.connect(transfer.from_url) do |c|
                                                  c.fetch("SELECT version()").get(:version)
                                                end)
                 source_bytes = Sequel.connect(transfer.from_url) do |c|
                   c.fetch("SELECT pg_database_size(current_database()) AS size").get(:size)
                 end
                 transfer.update(source_bytes: source_bytes)
                 pg_root = if to_version.nil? || from_version > to_version
                             "/app/bin/pg/#{from_version.major_minor}"
                           else
                             "/app/bin/pg/#{to_version.major_minor}"
                           end
                 PGDumpSource.new(transfer.from_url,
                                  opts: {
                                    no_owner: true,
                                    no_privileges: true,
                                    verbose: true,
                                    format: 'custom'
                                  },
                                  root: pg_root,
                                  logger: logger)
               when 'gof3r'
                 Gof3rSource.new(transfer.from_url, logger: logger)
               when 'htcat'
                 HtcatSource.new(transfer.from_url, logger: logger)
               else
                 raise ArgumentError, "Unkown transfer source type: #{from_type}"
               end
      DataMover.new(source, sink)
    end
  end

  class ShellFuture
    # The arguments are the return values of popen
    attr_reader :stdin, :stdout, :stderr
    def initialize(stdin, stdout, stderr, wthr)
      @stdin, @stdout, @stderr = stdin, stdout, stderr
      @wthr = wthr
      @log_threads = []
    end

    # Asynchronously write each line of of stdout to the +log+
    # function, which must accept a single String argument, then close
    # the stream (+wait+ will wait for output to be drained before
    # returning).
    def drain_stdout(logger)
      drain_stream(@stdout, logger)
    end

    # Same as drain_stdout, but for standard error.
    def drain_stderr(logger)
      drain_stream(@stderr, logger)
    end

    # If the thread is running, process.wait has not returned,
    # and the process is alive
    def alive?
      @wthr.alive?
    end

    # Wait for the process to finish. Returns the resulting
    # Process::Status of the process.
    def wait
      status = @wthr.value

      @log_threads.each { |thr| thr.join }
      [ @stdin, @stdout, @stderr ].each do |stream|
        stream.close unless stream.closed?
      end
      status
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

    private

    def drain_stream(stream, logger)
      @log_threads << Thread.new do
        begin
          stream.each_line { |l| logger.call(l.strip) }
        ensure
          stream.close
        end
      end
    end
  end

  module Commandable
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

    def run_command(env={}, cmd)
      stdin, stdout, stderr, wthr = Open3.popen3(env, *cmd)
      ShellFuture.new(stdin, stdout, stderr, wthr)
    end
  end

  # A source that runs pg_dump
  class PGDumpSource
    include Commandable
    extend Forwardable

    def_delegators :@future, :cancel

    def initialize(url, opts: {}, logger:, root:)
      uri = URI.parse(url)
      dbname = uri.path[1..-1]
      @env = { "LD_LIBRARY_PATH" => "#{root}/lib", "PGPASSWORD" => uri.password }
      @cmd = command("#{root}/bin/pg_dump",
                     opts.merge(username: uri.user,
                                host: uri.host,
                                port: uri.port || 5432), dbname)
      @logger = logger
    end

    def run_async
      @logger.call("Running #{@cmd.join(' ')}", level: :internal)
      @future = run_command(@env, @cmd)
      @future.drain_stderr(@logger)
      @future.stdout
    end

    def wait
      return @succeeded unless @succeeded.nil?

      @logger.call "waiting for pg_dump to complete"
      result = @future.wait
      @logger.call "pg_dump done"
      @logger.call("exit status details: #{result.inspect}", level: :internal)

      @succeeded = result.success? == true
    end

    def alive?
      @future && @future.alive?
    end
  end

  # A Sink that uploads to S3
  class Gof3rSink
    include Commandable
    extend Forwardable

    def_delegators :@future, :cancel

    def initialize(url, opts: {}, logger:)
      # assumes https://bucket.as3.amazonaws.com/key/path URIs
      uri = URI.parse(url)
      hostname = uri.hostname
      bucket = hostname.split('.').shift
      key = uri.path.sub(/\A\//, '')
      # gof3r put -b $bucket -k $key -m x-amz-server-side-encryption:AES256;
      # we assume the S3 keys are in the environment for now.
      @cmd = command(%W(gof3r put), { b: bucket, k: key,
                                      m: 'x-amz-server-side-encryption:AES256'})
      @logger = logger
    end

    def run_async
      @logger.call("Running #{@cmd.join(' ')}", level: :internal)
      @future = run_command(@cmd)
      @future.drain_stdout(@logger)
      @future.drain_stderr(->(line) { @logger.call(line, level: :internal) })
      @future.stdin
    end

    def wait
      return @succeeded unless @succeeded.nil?

      @logger.call "waiting for upload to complete"
      result = @future.wait
      @logger.call "upload done"
      @logger.call("exit status details: #{result.inspect}", level: :internal)

      @succeeded = result.success? == true
    end

    def alive?
      @future.alive?
    end
  end

  # A Sink that restores a custom-format Postgres dump into a database
  class PGRestoreSink
    include Commandable
    extend Forwardable

    def_delegators :@future, :cancel

    def initialize(url, opts: {}, logger:, root:)
      uri = URI.parse(url)
      dbname = uri.path[1..-1]
      @env = { "LD_LIBRARY_PATH" => "#{root}/lib", "PGPASSWORD" => uri.password }
      @cmd = command("#{root}/bin/pg_restore",
                     opts.merge(username: uri.user,
                                host: uri.host,
                                port: uri.port || 5432,
                                dbname: dbname))
      @logger = logger
    end

    def run_async
      @logger.call("Running #{@cmd.join(' ')}}", level: :internal)
      @future = run_command(@env, @cmd)
      # We don't expect any output from stdout. Capture it anyway, but
      # keep it internal.
      @future.drain_stdout(->(line) { @logger.call(line, level: :internal) })
      # pg_restore basically uses two exit codes: 1 and 0. This means
      # we can't rely on exit status to tell us much of anything,
      # since there's no way for an unprivileged user to comment on an
      # extension, and that's a standard part of a pg_dump, and
      # there's no way to avoid these. Instead, we watch for these and
      # compare them against the total number of errors reported by
      # pg_restore. This is pretty gross (e.g., it does not work with
      # a localized pg_restore), but safer.
      @failed_extension_comment_count = 0
      @failed_plpgsql_create = false
      @pg_restore_error_count = 0
      @future.drain_stderr(->(line) do
                             if line =~ /\ACommand was: COMMENT ON EXTENSION /
                               @failed_extension_comment_count += 1
                             elsif line =~ /\ACommand was: CREATE(?: OR REPLACE)? PROCEDURAL LANGUAGE plpgsql;/
                               # N.B.: we do a boolean flag here instead of a count so that
                               # if for whatever crazy reason we see this multiple tiimes, it
                               # should fail to match the error count and the overall transfer
                               # will rightly fail.
                               @failed_plpgsql_create = true
                             elsif line =~ /\AWARNING: errors ignored on restore: (\d+)/
                               @pg_restore_error_count = $1.to_i
                             end
                             @logger.call(line)
                           end)
      @future.stdin
    end

    def wait
      return @succeeded unless @succeeded.nil?

      @logger.call "waiting for restore to complete"
      result = @future.wait
      @logger.call "restore done"
      @succeeded = result.success? == true

      if result.exitstatus == 1
        expected_err_count = @failed_extension_comment_count
        if @failed_plpgsql_create
          expected_err_count += 1
        end
        @succeeded = expected_err_count == @pg_restore_error_count
      end

      return @succeeded
    end

    def alive?
      @future.alive?
    end
  end

  # A source that runs Gof3r to fetch from an S3 URL we have access to
  class Gof3rSource
    include Commandable
    extend Forwardable

    def_delegators :@future, :cancel

    def initialize(url, opts: {}, logger:)
      # assumes https://bucket.as3.amazonaws.com/key/path URIs
      uri = URI.parse(url)
      hostname = uri.hostname
      bucket = hostname.split('.').shift
      key = URI.decode(uri.path.sub(/\A\//, ''))
      # gof3r get -b $bucket -k $key; we assume the S3 keys are in the
      # environment.
      @cmd = command(%W(gof3r get), { b: bucket, k: key})
      @url = url
      @logger = logger
    end

    def run_async
      @logger.call("Running #{@cmd.join(' ')}", level: :internal)
      @future = run_command(@cmd)
      @future.drain_stderr(@logger)
      @future.stdout
    end

    def wait
      return @succeeded unless @succeeded.nil?

      @logger.call "waiting for download to complete"
      result = @future.wait
      @logger.call "download done"
      @succeeded = result.success? == true
    end

    def alive?
      @future.alive?
    end
  end

  # A source that runs htcat to fetch from any URL
  class HtcatSource
    include Commandable
    extend Forwardable

    def_delegators :@future, :cancel

    def initialize(url, opts: {}, logger:)
      # htcat $url
      @cmd = command('htcat', {}, url)
      @uri = URI.parse(url)
      @logger = logger
    end

    def run_async
      @logger.call("Running htcat #{@uri.scheme} ...", level: :internal)
      @future = run_command(@cmd)
      @future.drain_stderr(@logger)
      @future.stdout
    end

    def wait
      return @succeeded unless @succeeded.nil?

      @logger.call "waiting for download to complete"
      @result = @future.wait
      @logger.call "download done"
      @succeeded = @result.success? == true
    end
  end
end
