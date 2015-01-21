module Transferatu
  class TransferWorker

    def initialize(status)
      @status = status
    end

    def perform(transfer)
      @status.update(transfer: transfer)
      runner = RunnerFactory.runner_for(transfer)

      progress_thr = Thread.new do
        while transfer.in_progress?
          if transfer.canceled?
            runner.cancel
            break
          end
          transfer.mark_progress(runner.processed_bytes)
          # Nothing to change, but we want to update updated_at
          @status.save
          sleep 5
        end
        transfer.mark_progress(runner.processed_bytes)
      end

      begin
        result = runner.run_transfer
        if result
          transfer.complete
        else
          transfer.fail
        end
      rescue StandardError => e
        transfer.log("Transfer failed for unexpected reason: #{e.message}\n #{e.backtrace.join("\n")}
", level: :internal)
        transfer.fail unless transfer.failed?
        raise
      end

      progress_thr.join
    ensure
      @status.update(transfer: nil)
    end

    def wait
      # randomize sleep to avoid lock-stepping workers into a single
      # sequence
      sleep 1 + 4 * rand
      # See above: we want to make sure we show progress when there's
      # nothing to do.
      @status.save
    end
  end
end
