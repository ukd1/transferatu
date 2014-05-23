require "spec_helper"

describe Endpoints::Transfers do
  include Committee::Test::Methods
  include Rack::Test::Methods

  def app
    Routes
  end

  it "GET /transfers" do
    get "/transfers"
    last_response.status.should eq(200)
    last_response.body.should eq("[]")
  end

  it "POST /transfers/:id" do
    post "/transfers"
    last_response.status.should eq(201)
    last_response.body.should eq("{}")
  end

  it "GET /transfers/:id" do
    get "/transfers/123"
    last_response.status.should eq(200)
    last_response.body.should eq("{}")
  end

  it "PATCH /transfers/:id" do
    patch "/transfers/123"
    last_response.status.should eq(200)
    last_response.body.should eq("{}")
  end

  it "DELETE /transfers/:id" do
    delete "/transfers/123"
    last_response.status.should eq(200)
    last_response.body.should eq("{}")
  end
end
