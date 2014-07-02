require "spec_helper"

module Transferatu
  describe Endpoints::Groups do
    include Committee::Test::Methods
    include Rack::Test::Methods

    def app
      Routes
    end

    # TODO: restore acceptance tests
    xit "GET /groups" do
      get "/groups"
      last_response.status.should eq(200)
      last_response.body.should eq("[]")
    end

    xit "POST /groups/:id" do
      post "/groups"
      last_response.status.should eq(201)
      last_response.body.should eq("{}")
    end

    xit "GET /groups/:id" do
      get "/groups/123"
      last_response.status.should eq(200)
      last_response.body.should eq("{}")
    end

    xit "PATCH /groups/:id" do
      patch "/groups/123"
      last_response.status.should eq(200)
      last_response.body.should eq("{}")
    end

    xit "DELETE /groups/:id" do
      delete "/groups/123"
      last_response.status.should eq(200)
      last_response.body.should eq("{}")
    end
  end
end
