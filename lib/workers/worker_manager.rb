module Transferatu
  class WorkerManager
    WORK_COMMAND = "bundle exec rake transfers:run"

    def initialize
      @heroku = PlatformAPI.connect_oauth(Config.heroku_api_token, cache: Moneta.new(:Null))
      @heroku_app_name = Config.heroku_app_name
    end

    def top_off_workers
      needed_worker_count = Config.worker_count.to_i - running_worker_count
      needed_worker_count.times do |i|
        run_worker(Config.worker_size)
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

    def running_worker_count
      @heroku.dyno.list(@heroku_app_name)
        .select { |process| process['command'] == WORK_COMMAND }
        .count
    end
  end
end
