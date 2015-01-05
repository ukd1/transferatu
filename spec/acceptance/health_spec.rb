require "spec_helper"

module Transferatu
  describe Middleware::Health do
    include Committee::Test::Methods
    include Rack::Test::Methods

    def app
      Routes
    end

    describe 'GET /health' do
      it 'passes' do
        get '/health'
        expect(last_response.status).to eq(200)
      end
    end
  end
end
