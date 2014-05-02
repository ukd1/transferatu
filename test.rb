#!/usr/bin/env ruby

# 1. open a pg_dump to SOURCE_URL, writing to stdout
# 2. open a gof3r writing to s3, feeding stdin from pg_dump stdout

require 'open3'
require 'thread'

$stdout.sync = $stderr.sync = true

def log(msg)
  puts msg
end

class FailedTransfer < StandardError; end

def transfer(from_url, bucket, key)
  logger = ->(line) { puts line }

  pg_dump = PgDump.new(from_url, {
    no_owner: true,
    no_privileges: true,
    verbose: true,
    format: 'custom'
  })
  log "starting dump"
  dump_stream = pg_dump.run_async(logger)
  log "started async dump"

  uploader = S3Upload.new(dump_stream, bucket, key)

  log "starting upload"
  uploader.run_async(logger)
  log "started async upload"

  dump_status = pg_dump.wait
  upload_status = uploader.wait

  unless dump_status.zero?
    raise FailedTransfer, "Oh snap: pg_dump exited with #{dump_status}"
  end
  unless upload_status.zero?
    raise FailedTransfer, "Oh snap: uploader exited with #{upload_status}"
  end
  log "completed successfully"
rescue StandardError => e
  puts "transfer failed: #{e.inspect}"
end

class PgDump
  def initialize(from_url, opts)
    @from_url = from_url
    @opts = opts
  end

  def run_async(logger)
    cmd = ['pg_dump']
    # TODO: only take whitelisted opts
    @opts.each do |k,v|
      cmd << "--#{k.to_s.gsub(/_/, '-')}"
      unless v == true
        cmd << v
      end
    end
    cmd << @from_url
    log "Running #{cmd.join(' ').sub(@from_url, 'postgres://...')}"
    stdin, @stdout, stderr, @wait_thr = Open3.popen3(*cmd)
    @stderr_thr = Thread.new do
      begin
        stderr.each_line { |l| logger.call(l) }
      ensure
        stderr.close
      end
    end
    @stdout
  rescue StandardError => e
    log "pg_dump failed: #{e.inspect}"
    raise
  ensure
    stdin.close unless stdin.nil?
  end

  def wait
    log "waiting for pg_dump to complete"
    # Process::Status object returned; return the actual exit status
    status = @wait_thr.value.exitstatus

    @stderr_thr.join
    @stdout.close

    log "pg_dump done; exited with #{status}"
    status
  end
end

class S3Upload
  def initialize(source, bucket, key, opts={})
    @source = source
    @bucket = bucket
    @key = key
    @opts = opts
  end

  def run_async(logger)
    # ./gof3r put -b $bucket -k $key
    cmd = %W(gof3r put -b #{@bucket} -k #{@key})
    @opts.each do |k,v|
      cmd << "--#{k.to_s.gsub(/_/, '-')}"
      unless v == true
        cmd << v
      end
    end

    lock = Mutex.new
    log "Running #{cmd.join(' ')}"
    stdin, stdout, stderr, @wait_thr = Open3.popen3(*cmd)
    @stdin_thr = Thread.new do
      chunk_size = 8 * 1024 * 1024
      copied, total = 0, 0

      begin
        until @source.closed
          copied += IO.copy_stream(@source, stdin, chunk_size)
          if copied >= chunk_size
            total += copied
            copied = 0
            lock.synchronize { logger.call("Uploaded #{total / (1024 * 1024)}MB") }
          end
        end
        lock.synchronize { logger.call("Done; uploaded #{total / (1024 * 1024)}MB total") }
      rescue IOError => e
        if e.message =~ /closed stream/
          # TODO: this *probably* means we're fine because the other
          # side closed the pipe? maybe? in testing, i get:
          # 2014-05-02T13:07:33.928817+00:00 app[worker.1]: ./test.rb:116:in `copy_stream': Bad file descriptor - fstat (Errno::EBADF)

        end
      ensure
        stdin.close
      end
    end

    @stdout_thr = Thread.new do
      begin
        stdout.each_line { |l| lock.synchronize { logger.call(l) } }
      ensure
        stdout.close
      end
    end

    @stderr_thr = Thread.new do
      begin
        stderr.each_line { |l| log("WARNING: stderr from gof3r: #{l}") }
      ensure
        stderr.close
      end
    end
  rescue StandardError => e
    log "upload failed: #{e.inspect}"
    raise
  end

  def wait
    log "waiting for upload to complete"
    # Process::Status object returned; return the actual exit status
    status = @wait_thr.value.exitstatus

    @stdin_thr.join
    @stdout_thr.join
    @stderr_thr.join

    log "upload done; exited with #{status}"
    status
  end
end

transfer(ENV['FROM_URL'], ENV['S3_BUCKET'], "test/fake-#{Time.now.to_i}.backup")
