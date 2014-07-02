require "spec_helper"

describe Transferatu::Endpoints::Groups do
  include Rack::Test::Methods

  def app
    Transferatu::Endpoints::Groups
  end

  before do
    password = 'passw0rd'
    @user = create(:user, password: password)
    @group = create(:group, user: @user)
    authorize @user.name, password
  end

  describe "GET /groups" do
    it "succeeds" do
      get "/groups"
      last_response.status.should eq(200)
    end
  end
end
