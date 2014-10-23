module Transferatu
  class WorkerManager
    include Pliny::Log

    WORK_COMMAND = "bundle exec rake transfers:run"

    def initialize
      @heroku = PlatformAPI.connect_oauth(Config.heroku_api_token, cache: Moneta.new(:Null))
      @heroku_app_name = Config.heroku_app_name
    end

    def check_workers
      return if AppStatus.quiesced?
      existing_workers = running_workers
      existing_statuses = WorkerStatus.check(*existing_workers.map { |w| w['name'] }).all

      # for each worker, make sure that it's "making progress"; ensure:
      #  - the worker was updated or created recently
      #  - if the worker has a transfer, that transfer has been updated recently
      failed = existing_statuses.select do |status|
        expect_progress_since = Time.now - 5.minutes
        worker_last_progress_at = status.updated_at || status.created_at
        transfer = status.transfer
        (worker_last_progress_at < expect_progress_since) ||
          (transfer && transfer.updated_at < expect_progress_since)
      end

      Pliny.log(method: 'WorkerManager#check_workers', failed_workers: failed.count)

      failed.each do |status|
        Pliny.log(method: 'WorkerManager#check_workers', step: 'killing-failed',
                  name: status.dyno_name,
                  uuid: status.uuid) do
          if status.transfer
            status.transfer.log "aborting stuck transfer"
            status.transfer.fail
          end
          kill_worker(status.dyno_name)
        end
      end

      needed_worker_count = Config.worker_count.to_i - (existing_workers.count - failed.count)

      Pliny.log(method: 'WorkerManager#check_workers', needed_workers: needed_worker_count)

      needed_worker_count.times do |i|
        Pliny.log(method: 'WorkerManager#check_workers', step: 'starting-new') do
          run_worker(Config.worker_size)
        end
      end
    end

    private

    def run_worker(size)
      @heroku.dyno.create(
        @heroku_app_name,
        command: WORK_COMMAND,
        size: size
      )
    end

    def kill_worker(uuid)
      @heroku.dyno.restart(@heroku_app_name, uuid)
    end

    def running_workers
      @heroku.dyno.list(@heroku_app_name)
        .select { |process| process['command'] == WORK_COMMAND }
    end
  end
end
