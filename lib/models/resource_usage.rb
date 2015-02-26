require 'digest'
require 'open3'

module Transferatu
  class ResourceUsage < Sequel::Model
    def id
      Digest::SHA256.hexdigest("#{created_at.to_f}:#{foreign_uuid}")
    end

    plugin :timestamps

    def self.tracking(uuid, *commands, track_every: 60)
      # While the process is running, record execution info periodically
      unless commands.all? { |c| c =~ /\A[a-zA-Z0-9_-]+\z/ }
        # Since we have no easy way to enforce quoting
        raise ArgumentError, "Non-ASCII command names not supported"
      end
      cmds_arg = commands.join(',')
      cmd = ['bash', '-c', <<-EOF ]
trap exit INT
while true
do
  ps -C #{cmds_arg} --no-headers -o comm,rss,vsz,pcpu; sleep #{track_every}
done
      EOF
      _, stdout, wthr = Open3.popen2(*cmd)
      # Copy the id; avoid referencing it from another thread
      worker_id = Socket.gethostname
      output_thread = Thread.new do
        begin
          stdout.each_line do |line|
            process_type, rss_kb, vsz_kb, pcpu = line.split(/\s+/)
            unless [ process_type, rss_kb, vsz_kb, pcpu ].any? { |item| item.nil? }
              self.create(foreign_uuid: uuid,
                          worker_id: worker_id,
                          process_type: process_type,
                          rss_kb: rss_kb,
                          vsz_kb: vsz_kb,
                          pcpu: pcpu)
            end
          end
        ensure
          stdout.close
        end
      end

      yield

      begin
        Process.kill("INT", wthr.pid)
      rescue Errno::ESRCH
        # Our monitoring thread died at some point. Bummer, but no big deal.
      end
      wthr.value
      output_thread.join
      nil
    end
  end
end
