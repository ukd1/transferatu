module Transferatu
  class Group < Sequel::Model
    plugin :timestamps
    plugin :paranoid

    many_to_one :user
    one_to_many :transfers
  end
end
