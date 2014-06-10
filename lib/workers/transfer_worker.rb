module Transferatu
  class TransferWorker
    def perform(transfer)
      runner = RunnerFactory.runner_for(transfer)

      progress_thr = Thread.new do
        # Because of the threading model, we can update the value in the other
        # thread and read it out and update the DB here. Thanks, GIL!
        while transfer.in_progress?
          if transfer.canceled?
            runner.cancel
            break
          end
          transfer.mark_progress(runner.processed_bytes)
          sleep 5
        end
      end

      begin
        result = runner.run_transfer
        if result
          transfer.complete
        else
          transfer.fail
        end
      rescue StandardError => e
        log("Transfer failed for unknown reason: #{e.message}\n #{e.backtrace.join("\n")}")
        transfer.fail unless transfer.failed?
        raise
      end

      progress_thr.join
    end
  end
end
