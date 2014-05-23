require "digest"

module Transferatu
  class Log < Sequel::Model
    def id
      Digest::SHA256.hexdigest("#{created_at.to_f}:#{foreign_uuid}")
    end
  end

  module Loggable
    def logger
      ->(message, severity) { log(message, severity) }
    end

    def log(msg, severity=:info)
      Transferatu::Log.create(foreign_uuid: self.uuid,
                              severity: severity.to_s,
                              message: msg.to_s.strip)
    end

    def logs(limit = 200)
      Transferatu::Log.select(:severity, :created_at, :message)
        .where(foreign_uuid: self.uuid)
        .order_by(Sequel.desc(:created_at)).limit(limit)
        .all
    end
  end
end
