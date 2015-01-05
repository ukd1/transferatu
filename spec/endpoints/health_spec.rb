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

        it "returns 200" do
          result = health.call(rack_env)
          expect(result[0]).to eq(200)
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
