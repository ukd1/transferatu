require "spec_helper"

module Transferatu
  describe Endpoints::Schedules do
    include Committee::Test::Methods
    include Rack::Test::Methods

    def app
      Routes
    end

    xit "GET /schedules" do
      get "/schedules"
      last_response.status.should eq(200)
      last_response.body.should eq("[]")
    end

    xit "POST /schedules/:id" do
      post "/schedules"
      last_response.status.should eq(201)
      last_response.body.should eq("{}")
    end

    xit "GET /schedules/:id" do
      get "/schedules/123"
      last_response.status.should eq(200)
      last_response.body.should eq("{}")
    end

    xit "PATCH /schedules/:id" do
      patch "/schedules/123"
      last_response.status.should eq(200)
      last_response.body.should eq("{}")
    end

    xit "DELETE /schedules/:id" do
      delete "/schedules/123"
      last_response.status.should eq(200)
      last_response.body.should eq("{}")
    end
  end
end
