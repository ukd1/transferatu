module Transferatu
  class TransferWorker

    def initialize(status)
      @status = status
    end

    def perform(transfer)
      @status.update(transfer: transfer)

      # TODO: break this out into an Executor mediator?

      runner = nil
      begin
        runner = RunnerFactory.runner_for(transfer)
        # We don't want to make the failure messages here too
        # explicit, since they may pertain to the internal details of
        # the service and not be useful to end-users trying to
        # diagnose failures. As we learn the more common specific
        # failure modes, we should address them more directly and
        # communicate them concretely.
      rescue Sequel::DatabaseError => e
        fail_transfer(transfer,
                      "Could not connect to database to initialize transfer",
                      e)
      rescue StandardError => e
        fail_transfer(transfer,
                      "Could not initialize transfer",
                      e)
      end

      return unless runner

      # Sequel model objects are not safe for concurrent access, so
      # make sure we give the progress thread its own copy
      xfer_id = transfer.uuid
      progress_thr = Thread.new do
        xfer = Transfer[xfer_id]
        while xfer.in_progress? do
          xfer.mark_progress(runner.processed_bytes)
          # Nothing to change, but we want to update updated_at to
          # report in
          @status.save
          sleep 5
          xfer.reload
        end
        if xfer.canceled?
          runner.cancel
        else
          # Flag final progress
          xfer.mark_progress(runner.processed_bytes)
        end
      end

      begin
        result = runner.run_transfer
        if result
          transfer.complete
        else
          transfer.fail
        end
      rescue AlreadyFailed
        # ignore; if the transfer was canceled or otherwise failed
        # out of band, there's not much for us to do
      rescue StandardError => e
        transfer.log("Transfer failed for unexpected reason: #{e.message}\n #{e.backtrace.join("\n")}
", level: :internal)
        transfer.fail unless transfer.failed?
        raise
      end

      progress_thr.join

      Transferatu::Mediators::Transfers::Evictor
        .run(transfer: transfer)
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

    private

    def fail_transfer(transfer, message, exception)
      transfer.fail
      transfer.log message
      transfer.log exception.message, level: :internal
      exception.backtrace.each do |line|
        transfer.log line, level: :internal
      end
    end
  end
end
