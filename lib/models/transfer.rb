module Transferatu
  class Transfer < Sequel::Model

    include Transferatu::Loggable

    plugin :timestamps

  end
end
