require "bundler"
Bundler.require

require "./lib/initializer"
require "clockwork"

$stdout.sync = true

class LogStub
  # Pliny does not make it easy to log without actually including the
  # module right now, so we have this as a workaround
  include Pliny::Log
end

module Clockwork
  logger = LogStub.new

  every(1.minute, "top-off-workers") do
    Transferatu::WorkerManager.new.top_off_workers
  end

  every(1.minute, "log-metrics") do
    pending_xfer_count = Transferatu::Transfer.pending.count
    active_xfer_count = Transferatu::Transfer.in_progress.count
    logger.log(:"sample#pending_xfer_count" => pending_xfer_count,
               :"sample#active_xfer_count" => active_xfer_count)
  end

  every(4.hours, "mark-restart") do
    Transferatu::AppStatus.mark_update
  end
end
