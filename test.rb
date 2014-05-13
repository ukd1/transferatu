#!/usr/bin/env ruby

# 1. open a pg_dump to SOURCE_URL, writing to stdout
# 2. open a gof3r writing to s3, feeding stdin from pg_dump stdout

require 'sequel'

require 'open3'
require 'thread'

DB = Sequel.connect(ENV['DATABASE_URL'])

def setup_db
  require 'sequel/extensions/migration'
  Sequel::Migrator.apply(DB, 'migrations')
end

$stdout.sync = $stderr.sync = true

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
        until @source.eof?
          copied += IO.copy_stream(@source, stdin, chunk_size)
          if copied >= chunk_size
            total += copied
            copied = 0
            lock.synchronize { logger.call("Uploaded #{total / (1024 * 1024)}MB") }
          end
        end
        lock.synchronize { logger.call("Done; uploaded #{total / (1024 * 1024)}MB total") }
      rescue IOError => e
        puts "Failed to process incoming upload data: #{e.inspect}"
        raise
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

class Transfer < Sequel::Model
  one_to_many :logs

  def initialize(args)
    super
    @lock = Mutex.new
  end

  def log(msg)
    @lock.synchronize do
      puts msg
      self.add_log(message: msg)
    end
  end

  def perform
    bucket = ENV['S3_BUCKET']

    logger = ->(line) { self.log(line) }

    pg_dump = PgDump.new(self.from_url, {
                           no_owner: true,
                           no_privileges: true,
                           verbose: true,
                           format: 'custom'
                         })
    log "starting dump"
    dump_stream = pg_dump.run_async(logger)
    log "started async dump"

    uploader = S3Upload.new(dump_stream, bucket, self.s3_key)

    log "starting upload"
    uploader.run_async(logger)
    log "started async upload"

    dump_status = pg_dump.wait
    upload_status = uploader.wait

    log "pg_dump exited with #{dump_status}"
    log "uploader exited with #{upload_status}"

    exit_status = if dump_status.zero?
                    upload_status
                  else
                    dump_status
                  end

  rescue StandardError => e
    log "transfer failed: #{e.inspect}\n#{e.backtrace.join("\n")}"
  ensure
    self.update(exit_status: exit_status, finished_at: Time.now)
    self.log "transfer completed with exit status #{exit_status}"
  end
end

class Log < Sequel::Model
  many_to_one :transfer
end

setup_db

from_url = ENV['FROM_URL']
from_size = Sequel.connect(from_url) do |c|
  c.fetch("SELECT pg_database_size(current_database()) AS size").all.first[:size]
end

t = Transfer.create(
    from_url: from_url,
    s3_key: "test/fake-#{Time.now.to_i}.backup",
    db_size_bytes: from_size
  )
t.perform
