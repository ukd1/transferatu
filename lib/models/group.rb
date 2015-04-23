module Transferatu
  class Group < Sequel::Model
    plugin :timestamps
    plugin :paranoid

    many_to_one :user
    one_to_many :transfers
    one_to_many :schedules

    attr_secure :log_input_url, :secret => Config.at_rest_fernet_secret

    def active_backups
      self.transfers_dataset.where(to_type: 'gof3r', deleted_at: nil)
    end

    def log(message)
      # TODO: restore sending logs to logplex: we've had issues with
      # this stalling progress when it can't reach logplex. Logs are
      # already available in the database and exposed through the transfer
      # API, so just rely on that for now.
    end
  end
end
