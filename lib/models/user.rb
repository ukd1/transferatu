module Transferatu
  class User < Sequel::Model
    include Transferatu::Loggable
    plugin :timestamps
    one_to_many :transfers
  end
end
