require "spec_helper"

describe Endpoints::Transfers do
  include Rack::Test::Methods

  def app
    Endpoints::Transfers  end

  describe "GET /transfers" do
    it "succeeds" do
      get "/transfers"
      last_response.status.should eq(200)
    end
  end
end
