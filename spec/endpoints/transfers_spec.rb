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
      @group = create(:group, user: @user)
      authorize @user.name, password
    end

    describe "GET /groups/:name/transfers" do
      it "lists transfers for the group" do
        get "/groups/#{@group.name}/transfers"
        last_response.status.should eq(200)
      end
    end

    describe "GET /groups/:name/transfers/:id" do
      let(:xfer) { create(:transfer, group: @group) }

      it "succeeds" do
        get "/groups/#{@group.name}/transfers/#{xfer.uuid}"
        last_response.status.should eq(200)
      end
    end

    describe "POST /groups/:name/transfers" do
      before do
        header "Content-Type", "application/json"
      end
      it "succeeds" do
        post "/groups/#{@group.name}/transfers", JSON.generate(
                                                 from_type: 'pg_dump',
                                                 from_url:  'postgres:///test1',
                                                 to_type:   'pg_restore',
                                                 to_url:    'postgres:///test2'
                                               )
        last_response.status.should eq(201)
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
        last_response.status.should eq(201)
      end
    end
  end
end
