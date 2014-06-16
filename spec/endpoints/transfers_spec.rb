require "spec_helper"

module Transferatu::Endpoints
  describe Transfers do
    include Rack::Test::Methods

    def app
      Transfers
    end

    describe "GET /transfers" do
      # TODO: fix; fails because of auth issues
      xit "succeeds" do
        get "/transfers"
        last_response.status.should eq(200)
      end
    end
  end
end
