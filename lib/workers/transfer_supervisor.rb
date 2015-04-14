module Transferatu
  module TransferSupervisor
    def self.run
      started_at = Time.now
      status = Transferatu::WorkerStatus.create
      worker = TransferWorker.new(status)
      loop do
        if AppStatus.updated_at > started_at
          Pliny.log(method: 'TransferSupervisor.run', step: 'stale-worker-exiting')
          break
        end
        if AppStatus.quiesced?
          # update status even when quiesced so we don't go around
          # killing innocent workers
          status.save
          sleep 5
        else
          run_next(worker)
        end
      end
    end

    def self.run_next(worker)
      transfer = Transfer.begin_next_pending
      if transfer
        if transfer.options["trace"]
          Transferatu::ResourceUsage.tracking(transfer.uuid,
                                              transfer.from_type,
                                              transfer.to_type,
                                              'ruby') do
            worker.perform(transfer)
          end
        else
          worker.perform(transfer)
        end
      else
        worker.wait
      end
    end
  end
end
