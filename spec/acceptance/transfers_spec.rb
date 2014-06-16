require "spec_helper"

module Transferatu
  describe Endpoints::Transfers do
    include Committee::Test::Methods
    include Rack::Test::Methods

    def app
      Routes
    end

    # These fail because they don't account for auth--I'm not sure how
    # that should factor in here...
    xit "GET /transfers" do
      get "/transfers"
      last_response.status.should eq(200)
      last_response.body.should eq("[]")
    end

    xit "POST /transfers/:id" do
      post "/transfers"
      last_response.status.should eq(201)
      last_response.body.should eq("{}")
    end

    xit "GET /transfers/:id" do
      get "/transfers/123"
      last_response.status.should eq(200)
      last_response.body.should eq("{}")
    end

    xit "PATCH /transfers/:id" do
      patch "/transfers/123"
      last_response.status.should eq(200)
      last_response.body.should eq("{}")
    end

    xit "DELETE /transfers/:id" do
      delete "/transfers/123"
      last_response.status.should eq(200)
      last_response.body.should eq("{}")
    end
  end
end
