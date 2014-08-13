require "spec_helper"

describe Transferatu::Endpoints::Groups do
  include Rack::Test::Methods

  def app
    Transferatu::Endpoints::Groups
  end

  before do
    @user = create(:user)
    @group = create(:group, user: @user)
    Transferatu::RequestStore.current_user = @user
  end

  describe "GET /groups" do
    it "succeeds" do
      get "/groups"
      last_response.status.should eq(200)
    end
  end

  describe "GET /groups/:name" do
    it "succeeds" do
      get "/groups/#{@group.name}"
      last_response.status.should eq(200)
    end
  end

  describe "POST /groups" do
    before do
      header "Content-Type", "application/json"
    end
    it "succeeds" do
      post "/groups", JSON.generate(name: 'foo')
      last_response.status.should eq(201)
    end
    it "responds with 409 Conflict if group already exists" do
      post "/groups", JSON.generate(name: @group.name)
      last_response.status.should eq(409)
    end
  end

  describe "DELETE /groups/:name" do
    it "succeeds" do
      delete "/groups/#{@group.name}"
      last_response.status.should eq(200)
    end
    it "responds with 404 on missing groups" do
      delete "/groups/not-a-real-group"
      last_response.status.should eq(404)
    end
  end
end
