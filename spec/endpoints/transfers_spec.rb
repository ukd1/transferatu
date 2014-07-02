require "spec_helper"

module Transferatu::Endpoints
  describe Transfers do
    include Rack::Test::Methods

    def app
      Transfers
    end

    before do
      password = 'passw0rd'
      @user = create(:user, password: password)
      authorize @user.name, password
      @group = create(:group, user: @user)
    end

    describe "GET /groups/:name/transfers" do
      it "succeeds" do
        get "/groups/#{@group.name}/transfers"
        last_response.status.should eq(200)
      end
    end
  end
end
