module Transferatu
  module TransferSupervisor
    def run
      worker = TransferWorker.new
      loop do
        transfer = Transfer.begin_next_pending(t)
        worker.perform(transfer)
        sleep 5 * rand
      end
    end
  end
end

