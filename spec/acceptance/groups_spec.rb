require "spec_helper"

module Transferatu
  describe Endpoints::Groups do
    include Committee::Test::Methods
    include Rack::Test::Methods

    def app
      Routes
    end

    before do
      @password = 'hunter2'
      @user = create(:user, password: @password)
    end

    describe "when unauthenticated" do
      it "rejects requests" do
        get "/groups"
        expect(last_response.status).to eq(401)
        response = JSON.parse(last_response.body)

        expect(response["message"]).to match("Unauthorized")
        expect(response["status"]).to eq(401)
      end
    end

    describe "when authenticated" do
      before do
        authorize @user.name, @password
      end

      it "GET /groups" do
        get "/groups"
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq([])
      end

      it "POST /groups" do
        data = { name: 'group1', log_input_url: 'https://example.com/logs' }
        post "/groups", data
        expect(last_response.status).to eq(201)
        response = JSON.parse(last_response.body)
        data.keys.each do |key|
          expect(response[key.to_s]).to eq data[key]
        end
        group_id = response["uuid"]
        expect(group_id).to_not be_nil
        group = Transferatu::Group[group_id]
        data.keys.each do |key|
          expect(group.public_send(key)).to eq data[key]
        end
      end

      it "GET /groups/:name" do
        group = create(:group, user: @user)
        get "/groups/#{group.name}"
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        %i(name log_input_url).each do |field|
          expect(response[field.to_s]).to eq(group.public_send(field))
        end
      end

      it "DELETE /groups/:name/transfers/:id" do
        group = create(:group, user: @user)
        before_deletion = Time.now
        delete "/groups/#{group.name}"
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        %i(name log_input_url).each do |field|
          expect(response[field.to_s]).to eq(group.public_send(field))
        end
        group.reload
        expect(group.deleted?).to be true
        expect(group.deleted_at).to be > before_deletion
        expect(group.deleted_at).to be < Time.now
      end
    end
  end
end
