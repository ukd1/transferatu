module Transferatu
  class AppStatus < Sequel::Model(:app_status)
    def self.create(*args)
      raise StandardError, "app status already exists"
    end

    def self.mark_update
      self.first.update(updated_at: Time.now)
    end

    def self.quiesce
      self.first.update(quiesced: true, updated_at: Time.now)
    end

    def self.resume
      self.first.update(quiesced: false, updated_at: Time.now)
    end

    def self.quiesced?
      self.first.quiesced
    end

    def self.updated_at
      self.first.updated_at
    end
  end
end
