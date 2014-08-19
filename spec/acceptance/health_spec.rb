require "spec_helper"

module Transferatu
  describe Middleware::Health do
    include Committee::Test::Methods
    include Rack::Test::Methods

    def app
      Routes
    end

    describe 'GET /health' do
      it 'passes when there are no pending transfers' do
        get '/health'
        expect(last_response.status).to eq(200)
      end

      it 'fails when there are pending transfers without updates' do
        t1 = create(:transfer)
        t1.db.execute <<-SQL
UPDATE transfers SET started_at = now() - interval '3 hours',
  updated_at = now() - interval '10 minutes' WHERE uuid = '#{t1.uuid}'
          SQL
        get '/health'
        expect(last_response.status).to eq(503)
      end
    end
  end
end
