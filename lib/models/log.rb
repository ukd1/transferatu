require "digest"

module Transferatu
  class Log < Sequel::Model
    def id
      Digest::SHA256.hexdigest("#{created_at.to_f}:#{foreign_uuid}")
    end
  end

  class ThreadSafeLogger
    def initialize(model)
      @model = model.clone
      @mutex = Mutex.new
    end

    def log(line, opts={})
      @mutex.synchronize do
        @model.log(line, opts)
      end
    end
  end

  module Loggable
    def log(msg, level: :info)
      if block_given?
        log_line("starting: #{msg.to_s.strip}", level)
        begin
          yield
          log_line("finished: #{msg.to_s.strip}", level)
        rescue StandardError => e
          unless level == :internal
            level = :error
          end
          log_line("raised #{e.class}: #{msg.to_s.strip}", level)
          raise
        end
      else
        log_line(msg, level)
      end
    end

    def logs(limit: 200)
      logs_dataset = Log.select(:level, :created_at, :message)
        .where(foreign_uuid: self.uuid)
        .order_by(Sequel.desc(:created_at))
      if limit > 0
        logs_dataset = logs_dataset.limit(limit)
      end
      logs_dataset.all
    end

    private

    def log_line(msg, level)
      Log.create(foreign_uuid: self.uuid,
                 level: level.to_s,
                 message: msg.to_s.strip)
    end
  end
end
