require "spec_helper"

module Transferatu::Middleware
  describe Health do
    let(:app)       { double(:app) }
    let(:rack_env)  { {} }

    let(:health) { Health.new(app) }

    describe "#call" do
      context "for the /health endpoint" do
        before do
          rack_env["PATH_INFO"] = '/health'
        end

        it "returns 200 when there are no in-progress transfers" do
          result = health.call(rack_env)
          expect(result[0]).to eq(200)
        end

        it "returns 200 when all in-progress transfers are making progress" do
          t1 = create(:transfer)
          t2 = create(:transfer)
          # this also updates updated_at for us
          t1.update(started_at: Time.now - 3.hours)
          t2.update(started_at: Time.now - 2.hours)
          result = health.call(rack_env)
          expect(result[0]).to eq(200)
        end

        it "returns 503 when any in-progress transfers are not making progress" do
          t1 = create(:transfer)
          t2 = create(:transfer)
          # unfortunately, the timestamps plugin doesn't support
          # manual setting of updated_at
          t1.db.execute <<-SQL
UPDATE transfers SET started_at = now() - interval '3 hours',
  updated_at = now() - interval '10 minutes' WHERE uuid = '#{t1.uuid}'
          SQL
          t2.db.execute <<-SQL
UPDATE transfers SET started_at = now() - interval '2 hours',
  updated_at = now() - interval '12 minutes' WHERE uuid = '#{t2.uuid}'
          SQL
          t1.reload; t2.reload
          result = health.call(rack_env)
          expect(result[0]).to eq(503)
        end

        it "does not propagate the request" do
          expect(app).to_not receive(:call).with(rack_env)
          health.call(rack_env)
        end
      end

      context "for other endpoints" do
        ["healths", " health", "health\n"].each do |endpoint|
          it "passes through calls to endpoint '#{endpoint}'" do
            rack_env["PATH_INFO"] = endpoint
            expect(app).to receive(:call).with(rack_env)
            health.call(rack_env)
          end
        end
      end
    end
  end
end
