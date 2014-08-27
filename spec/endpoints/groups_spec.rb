require "spec_helper"

describe Transferatu::Endpoints::Groups do
  include Rack::Test::Methods

  def app
    Transferatu::Endpoints::Groups
  end

  let(:log_url) { 'https://token:t.8cda5772-ba01-49ec-9431-4391a067a0d3@example.com/logs' }

  before do
    @user = create(:user)
    @group = create(:group, user: @user)
    Transferatu::RequestStore.current_user = @user
  end

  describe "GET /groups" do
    it "succeeds" do
      get "/groups"
      expect(last_response.status).to eq(200)
    end
  end

  describe "GET /groups/:name" do
    it "succeeds" do
      get "/groups/#{@group.name}"
      expect(last_response.status).to eq(200)
    end
  end

  describe "POST /groups" do
    before do
      header "Content-Type", "application/json"
    end
    it "succeeds" do
      post "/groups", JSON.generate(name: 'foo', log_input_url: log_url)
      expect(last_response.status).to eq(201)
    end
    it "responds with 409 Conflict if group already exists" do
      post "/groups", JSON.generate(name: @group.name, log_input_url: log_url)
      expect(last_response.status).to eq(409)
    end
  end

  describe "DELETE /groups/:name" do
    it "succeeds" do
      delete "/groups/#{@group.name}"
      expect(last_response.status).to eq(200)
    end
    it "responds with 404 on missing groups" do
      delete "/groups/not-a-real-group"
      expect(last_response.status).to eq(404)
    end
  end
end
