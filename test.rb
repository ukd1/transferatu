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

class Log < Sequel::Model
  many_to_one :transfers
end

class Transfer < Sequel::Model
  one_to_many :logs

  def initialize
    @lock ||= Mutex.new
  end

  def log(msg)
    @lock.synchronize do
      puts msg
      self.add_log(msg)
    end
  end

  def perform
    bucket = ENV['S3_BUCKET']
    from = self.from_url
    key = self.s3_key
    cmd = ['bash', '-o', 'pipefail', '-c', "pg_dump --verbose --no-owner --no-privileges --format custom #{from} | pv --name 'upload progress' --bytes --force | gof3r put -b #{bucket} -k #{key}"]
    result = nil
    self.log "running upload pipeline"
    Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
      stdout_thr = Thread.new do
        begin
          stdout.each_line { |l| self.log("stderr: #{l}") }
        ensure
          stdout.close
        end
      end
      stderr_thr = Thread.new do
        begin
          stderr.each_line { |l| self.log("stdout: #{l}") }
        ensure
          stderr.close
        end
      end

      result = wait_thr.value.exitstatus
      stdout_thr.join
      stderr_thr.join
    end
    self.update(exit_status: result, finished_at: Time.now)
    self.log "transfer completed with exit status #{result}"
  end
end

setup_db

from_url = ENV['FROM_URL']
from_size = Sequel.connect(from_url) do |c|
  c.fetch("SELECT pg_database_size(current_database()) AS size").all.first[:size]
end

t = Transfer.create(
    from_url: from_url,
    s3_key: "test/fake-#{Time.now.to_i}.backup",
    db_size: from_size
  )
t.perform
