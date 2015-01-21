module Transferatu
  class TransferWorker

    def initialize(status)
      @status = status
    end

    def perform(transfer)
      @status.update(transfer: transfer)
      runner = RunnerFactory.runner_for(transfer)

      # Sequel model objects are not safe for concurrent access, so
      # make sure we give the progress thread its own copy
      xfer_id = transfer.uuid
      progress_thr = Thread.new do
        xfer = Transfer[xfer_id]
        loop do
          break unless xfer.in_progress?
          if xfer.canceled?
            runner.cancel
            break
          end
          xfer.mark_progress(runner.processed_bytes)
          # Nothing to change, but we want to update updated_at to
          # report in
          @status.save
          sleep 5
          xfer.reload
        end
        xfer.mark_progress(runner.processed_bytes)
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
