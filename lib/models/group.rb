module Transferatu
  class Group < Sequel::Model
    plugin :timestamps
    plugin :paranoid

    many_to_one :user
    one_to_many :transfers
    one_to_many :schedules

    attr_secure :log_input_url, :secret => Config.at_rest_fernet_secret

    def log(message)
      # N.B.: we leak two threads per logplex endpoint here due to
      # the structure of lpxc, but given the low number of endpoints,
      # this is tolerable
      Lpxc.puts(message, log_input_url, procid: Config.logplex_procid)
    end
  end
end
