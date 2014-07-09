require "./lib/initializer"
require "clockwork"

module Clockwork
  every(1.minute, "top-off-workers") do
    Transferatu::WorkerManager.new.top_off_workers
  end

  every(4.hours, "mark-restart") do
    Transferatu::AppStatus.mark_restart
  end
end
