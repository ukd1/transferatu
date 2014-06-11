module Transferatu
  module TransferSupervisor
    def self.run
      worker = TransferWorker.new
      loop do
        run_next(worker)
      end
    end

    def self.run_next(worker)
      transfer = Transfer.begin_next_pending
      if transfer
        worker.perform(transfer)
      else
        # randomize sleep to avoid lock-stepping workers into a single
        # sequence
        sleep 1 + 4 * rand
      end
    end
  end
end
