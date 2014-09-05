require 'spec_helper'

module Transferatu
  describe Transferatu::ScheduleResolver do
    let(:resolver)  { Transferatu::ScheduleResolver.new }
    let(:schedule)  { create(:schedule) }
    let(:xfer_info) { {
                       "from_type" => 'pg_dump',
                       "from_url" => 'postgres:///test1',
                       "from_name" => 'eunice',
                       "to_type" => 'gof3r',
                       "to_url" => 'auto',
                       "to_name" => 'joel',
                       "options" => {}
                      } }
    let(:resource)  { double(:resource) }

    describe "#resolve" do
      before do
        expect(RestClient::Resource).to receive(:new)
          .with(schedule.callback_url,
                user: schedule.group.user.name,
                password: schedule.group.user.callback_password,
                headers: { content_type: 'application/octet-stream',
                          accept: 'application/octet-stream' })
          .and_return(resource)
      end

      [ RestClient::Gone, RestClient::ResourceNotFound ].each do |error|
        it "returns nil when invoking the callback url raises #{error}" do
          expect(resource).to receive(:get).and_raise error
          resolver.resolve(schedule)
        end
      end

      it "returns the decrypted transfer data from the callback when successful" do
        expect(resource).to receive(:get).and_return(JSON.generate(xfer_info))
        resolved = resolver.resolve(schedule)
        expect(resolved).to eq(xfer_info)
      end
    end
  end
end
