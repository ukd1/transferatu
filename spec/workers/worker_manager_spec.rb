require 'spec_helper'

module Transferatu
  describe WorkerManager do
    let(:platform_api)  { double(:platform_api, dyno: dyno_api) }
    let(:dyno_api)     { double(:dynos) }
    let(:app_name)      { 'transferatu' }
    let(:api_token)     { 'a super-secret token' }
    let(:worker_count)  { 5 }
    let(:worker_size)   { '2X' }

    let(:manager)       { WorkerManager.new }

    describe "#top_off_workers" do
      before do
        Config.stub(heroku_app_name: app_name,
                    heroku_api_token: api_token,
                    worker_count: worker_count,
                    worker_size: worker_size)
        PlatformAPI.should_receive(:connect_oauth).and_return(platform_api)
      end

      def make_dynos(workers:, others: 0)
        template = {
          "attach_url" => "rendezvous://rendezvous.runtime.heroku.com:5000/1234",
          "command" => "<replace-me>",
          "created_at" => "2012-01-01T12:00:00Z",
          "id" => "01234567-89ab-cdef-0123-456789abcdef",
          "name" => "run.1",
          "release" => { "id" => "01234567-89ab-cdef-0123-456789abcdef", "version" => 11 },
          "size" => "1X",
          "state" => "up",
          "type" => "run",
          "updated_at" => "2012-01-01T12:00:00Z"
        }
        (workers + others).times.map do |i|
          dyno = template.clone
          dyno["command"] = if i < workers
                              WorkerManager::WORK_COMMAND
                            else
                              "sleep #{i}"
                            end
          dyno
        end
      end

      it "adds workers when needed" do
        dyno_api.should_receive(:list).with(app_name)
          .and_return(make_dynos(workers: 3))
        dyno_api.should_receive(:create).twice
          .with(app_name, command: WorkerManager::WORK_COMMAND, size: worker_size)
        manager.top_off_workers
      end

      it "ignores other processes when calculating needed worker counts" do
        dyno_api.should_receive(:list).with(app_name)
          .and_return(make_dynos(workers: 3, others: 5))
        dyno_api.should_receive(:create).twice
          .with(app_name, command: WorkerManager::WORK_COMMAND, size: worker_size)
        manager.top_off_workers
      end

      it "does not add workers when the appropriate number are running" do
        dyno_api.should_receive(:list).with(app_name)
          .and_return(make_dynos(workers: 5))
        dyno_api.should_not_receive(:create)
        manager.top_off_workers
      end

      it "does not add workers when too many are running" do
        dyno_api.should_receive(:list).with(app_name)
          .and_return(make_dynos(workers: 7))
        dyno_api.should_not_receive(:create)
        manager.top_off_workers
      end
    end
  end
end
