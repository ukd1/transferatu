module Transferatu
  module TransferSupervisor
    def self.run
      started_at = Time.now
      worker = TransferWorker.new
      loop do
        if AppStatus.updated_at > started_at
          log.info "Application has been updated; exiting"
          break
        end
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
