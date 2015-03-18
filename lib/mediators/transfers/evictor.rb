module Transferatu
  module Mediators::Transfers
    class Evictor < Mediators::Base
      def initialize(transfer:)
        @transfer = transfer
      end

      def call
        # TODO: right now, we explicitly hard-code 'gof3r' target
        # transfers for expiration here; ideally we should have
        # better-defined semantics
        to_delete = @transfer.group.transfers_dataset.present
          .where(from_name: @transfer.from_name, to_type: 'gof3r', succeeded: true)
          .order_by(Sequel.desc(:created_at))
          .offset(@transfer.num_keep)
        to_delete.each do |evicted|
          evicted.destroy
        end
      end
    end
  end
end
