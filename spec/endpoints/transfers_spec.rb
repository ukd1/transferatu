require "spec_helper"

module Transferatu::Endpoints
  describe Transfers do
    include Rack::Test::Methods

    def app
      Transfers
    end

    before do
      @user = create(:user)
      @group = create(:group, user: @user)
      Transferatu::RequestStore.current_user = @user
    end

    describe "GET /groups/:name/transfers" do
      it "lists transfers for the group" do
        get "/groups/#{@group.name}/transfers"
        expect(last_response.status).to eq(200)
      end

      it "does not include deleted transfers" do
        t = create(:transfer)
        t.destroy
        get "/groups/#{@group.name}/transfers"
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to be_empty
      end

      it "does not include transfers from other groups" do
        other_group = create(:group, user: @user)
        other_xfer = create(:transfer, group: other_group)
        get "/groups/#{@group.name}/transfers"
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body).find do |xfer|
                 xfer[:uuid] = other_xfer.uuid
                 end).to be_nil
      end
    end

    describe "GET /groups/:name/transfers/:id" do
      let(:xfer) { create(:transfer, group: @group) }

      it "looks up a transfer by uuid" do
        get "/groups/#{@group.name}/transfers/#{xfer.uuid}"
        expect(last_response.status).to eq(200)
      end

      it "looks up a transfer by its numeric id" do
        get "/groups/#{@group.name}/transfers/#{xfer.transfer_num}"
        expect(last_response.status).to eq(200)
      end

      it "does not include deleted transfers" do
        xfer.destroy
        get "/groups/#{@group.name}/transfers/#{xfer.uuid}"
        expect(last_response.status).to eq(410)
      end

      it "does not include transfers from other groups" do
        other_group = create(:group)
        get "/groups/#{other_group.name}/transfers/#{xfer.uuid}"
        expect(last_response.status).to eq(404)
      end

      it "includes logs with the verbose flag" do
        get "/groups/#{@group.name}/transfers/#{xfer.uuid}?verbose=true"
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)["logs"]).to_not be_nil
      end
    end

    describe "POST /groups/:name/transfers" do
      before do
        header "Content-Type", "application/json"
      end
      it "creates a transfer" do
        post "/groups/#{@group.name}/transfers", JSON.generate(
                                                 from_type: 'pg_dump',
                                                 from_url:  'postgres:///test1',
                                                 to_type:   'pg_restore',
                                                 to_url:    'postgres:///test2'
                                               )
        expect(last_response.status).to eq(201)
      end

      it "accepts optional from_name and to_name values" do
        post "/groups/#{@group.name}/transfers", JSON.generate(
                                                 from_type: 'pg_dump',
                                                 from_url:  'postgres:///test1',
                                                 from_name: 'arthur',
                                                 to_type:   'pg_restore',
                                                 to_url:    'postgres:///test2',
                                                 to_name:   'esther'
                                               )
        expect(last_response.status).to eq(201)
      end
    end

    describe "DELETE /groups/:name/transfers/:id" do
      let(:xfer) { create(:transfer, group: @group) }

      it "deletes a transfer by uuid" do
        delete "/groups/#{@group.name}/transfers/#{xfer.uuid}"
        expect(last_response.status).to eq(200)
      end

      it "deletes a transfer by its numeric id" do
        delete "/groups/#{@group.name}/transfers/#{xfer.transfer_num}"
        expect(last_response.status).to eq(200)
      end
    end
  end
end
