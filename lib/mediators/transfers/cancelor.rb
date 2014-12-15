module Transferatu
  module Mediators::Transfers
    class Cancelor < Mediators::Base
      def initialize(transfer:)
        @transfer = transfer
      end

      def call
        if @transfer.finished?
          raise ArgumentError, "Transfer cannot be canceled: it has already finished"
        end

        @transfer.cancel
      end
    end
  end
end
