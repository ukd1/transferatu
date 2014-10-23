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

    describe "#check_workers" do
      before do
        allow(Config).to receive_messages(heroku_app_name: app_name,
                    heroku_api_token: api_token,
                    worker_count: worker_count,
                    worker_size: worker_size)
        expect(PlatformAPI).to receive(:connect_oauth).and_return(platform_api)
      end

      def make_dynos(workers:, others: 0)
        template = {
          "attach_url" => "rendezvous://rendezvous.runtime.heroku.com:5000/1234",
          "created_at" => "2012-01-01T12:00:00Z",
          "name" => "run.1",
          "release" => { "id" => "01234567-89ab-cdef-0123-456789abcdef", "version" => 11 },
          "size" => "1X",
          "state" => "up",
          "type" => "run",
          "updated_at" => "2012-01-01T12:00:00Z"
        }
        (workers + others).times.map do |i|
          dyno = template.clone
          dyno["id"] = SecureRandom.uuid
          if i < workers
            dyno["command"] = WorkerManager::WORK_COMMAND
            dyno["name"] = "run.#{i}"
          else
            dyno["command"] = "sleep #{i}"
            dyno["name"] = "worker.#{i}"
          end
          create(:worker_status, dyno_name: dyno["name"])
          dyno
        end
      end

      context "when not quiesced" do
        before do
          expect(AppStatus).to receive(:quiesced?).and_return(false)
        end

        it "adds workers when needed" do
          expect(dyno_api).to receive(:list).with(app_name)
            .and_return(make_dynos(workers: 3))
          expect(dyno_api).to receive(:create).twice
            .with(app_name, command: WorkerManager::WORK_COMMAND, size: worker_size)
          manager.check_workers
        end

        it "ignores other processes when calculating needed worker counts" do
          expect(dyno_api).to receive(:list).with(app_name)
            .and_return(make_dynos(workers: 3, others: 5))
          expect(dyno_api).to receive(:create).twice
            .with(app_name, command: WorkerManager::WORK_COMMAND, size: worker_size)
          manager.check_workers
        end

        it "does not add workers when the appropriate number are running" do
          expect(dyno_api).to receive(:list).with(app_name)
            .and_return(make_dynos(workers: 5))
          expect(dyno_api).not_to receive(:create)
          manager.check_workers
        end

        it "does not add workers when too many are running" do
          expect(dyno_api).to receive(:list).with(app_name)
            .and_return(make_dynos(workers: 7))
          expect(dyno_api).not_to receive(:create)
          manager.check_workers
        end

        it "replaces workers that have never made progress and are older than five minutes" do
          dynos = make_dynos(workers: 5)
          expect(dyno_api).to receive(:list).with(app_name)
            .and_return(dynos)
          bad_dyno = dynos.first
          expect(dyno_api).to receive(:restart).with(app_name, bad_dyno["name"])
          expect(dyno_api).to receive(:create)
            .with(app_name, command: WorkerManager::WORK_COMMAND, size: worker_size)

          WorkerStatus.where(dyno_name: bad_dyno["name"]).update(created_at: Time.now - 4.hours)

          manager.check_workers
        end

        it "replaces workers that have not made progress in more than five minutes" do
          dynos = make_dynos(workers: 5)
          expect(dyno_api).to receive(:list).with(app_name).and_return(dynos)
          bad_dyno = dynos.first
          expect(dyno_api).to receive(:restart).with(app_name, bad_dyno["name"])
          expect(dyno_api).to receive(:create)
            .with(app_name, command: WorkerManager::WORK_COMMAND, size: worker_size)

          WorkerStatus.where(dyno_name: bad_dyno["name"])
            .update(created_at: Time.now - 4.hours,
                    updated_at: Time.now - 4.hours)

          manager.check_workers
        end

        it "replaces worker running a transfer that has not made progress in more than five minutes" do
          dynos = make_dynos(workers: 5)
          expect(dyno_api).to receive(:list).with(app_name).and_return(dynos)
          bad_dyno = dynos.first
          expect(dyno_api).to receive(:restart).with(app_name, bad_dyno["name"])
          expect(dyno_api).to receive(:create)
            .with(app_name, command: WorkerManager::WORK_COMMAND, size: worker_size)

          bad_transfer = create(:transfer)
          WorkerStatus.where(dyno_name: bad_dyno["name"]).update(transfer_id: bad_transfer.uuid)
          Transfer.where(uuid: bad_transfer.uuid).update(updated_at: Time.now - 4.hours)

          manager.check_workers
        end

        it "flags transfers of killed workers as failed" do
          dynos = make_dynos(workers: 1)
          expect(dyno_api).to receive(:list).with(app_name).and_return(dynos)
          bad_dyno = dynos.first
          allow(dyno_api).to receive(:restart)
          allow(dyno_api).to receive(:create)

          bad_transfer = create(:transfer)
          WorkerStatus.where(dyno_name: bad_dyno["name"]).update(transfer_id: bad_transfer.uuid)
          Transfer.where(uuid: bad_transfer.uuid).update(updated_at: Time.now - 4.hours)

          manager.check_workers

          bad_transfer.reload
          expect(bad_transfer.failed?).to be true
          expect(bad_transfer.logs.find { |l| l.message =~ /aborting stuck transfer/ }).not_to be_nil
        end
      end

      context "when quiesced" do
        before do
          expect(AppStatus).to receive(:quiesced?).and_return(true)
        end

        it "does not add workers" do
          expect(dyno_api).not_to receive(:list)
          expect(dyno_api).not_to receive(:create)
          manager.check_workers
        end
      end
    end
  end
end
