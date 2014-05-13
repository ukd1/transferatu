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

def transfer_pipe(from, bucket, key)
  cmd = ['bash', '-o', 'pipefail', '-c', "pg_dump --verbose --no-owner --no-privileges --format custom #{from} | pv --name 'upload progress' --bytes --force | gof3r put -b #{bucket} -k #{key}"]
  result = nil
  log "running upload pipeline"
  Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
    stdout_thr = Thread.new do
      begin
        stdout.each_line { |l| log("stderr: #{l}") }
      ensure
        stdout.close
      end
    end
    stderr_thr = Thread.new do
      begin
        stderr.each_line { |l| log("stdout: #{l}") }
      ensure
        stderr.close
      end
    end

    result = wait_thr.value.exitstatus
    stdout_thr.join
    stderr_thr.join
  end
  unless result == 0
    raise FailedTransfer, "Oh snap: upload pipeline failed with #{result}"
  end
  log "completed successfully"
end

transfer_pipe(ENV['FROM_URL'], ENV['S3_BUCKET'], "test/fake-#{Time.now.to_i}.backup")
