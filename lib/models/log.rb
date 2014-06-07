require "digest"

module Transferatu
  class Log < Sequel::Model
    def id
      Digest::SHA256.hexdigest("#{created_at.to_f}:#{foreign_uuid}")
    end
  end

  module Loggable
    def log(msg, severity: :info)
      if block_given?
        log_line("starting: #{msg.to_s.strip}", severity)
        begin
          yield
          log_line("finished: #{msg.to_s.strip}", severity)
        rescue StandardError => e
          unless severity == :internal
            severity = :error
          end
          log_line("raised #{e.class}: #{msg.to_s.strip}", severity)
          raise
        end
      else
        log_line(msg, severity)
      end
    end

    def logs(limit = 200)
      Log.select(:severity, :created_at, :message)
        .where(foreign_uuid: self.uuid)
        .order_by(Sequel.desc(:created_at)).limit(limit)
        .all
    end

    private

    def log_line(msg, severity)
      Log.create(foreign_uuid: self.uuid,
                 severity: severity.to_s,
                 message: msg.to_s.strip)
    end
  end
end
