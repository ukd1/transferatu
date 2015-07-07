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
        post "/groups/#{@group.name}/transfers",
          JSON.generate(from_type: 'pg_dump',
                        from_url:  'postgres:///test1',
                        to_type:   'pg_restore',
                        to_url:    'postgres:///test2')
        expect(last_response.status).to eq(201)
      end

      it "accepts optional from_name and to_name values" do
        post "/groups/#{@group.name}/transfers",
          JSON.generate(from_type: 'pg_dump',
                        from_url:  'postgres:///test1',
                        from_name: 'arthur',
                        to_type:   'pg_restore',
                        to_url:    'postgres:///test2',
                        to_name:   'esther')
        expect(last_response.status).to eq(201)
      end


      it "accepts optional num_keep value" do
        post "/groups/#{@group.name}/transfers",
          JSON.generate(from_type: 'pg_dump',
                        from_url:  'postgres:///test1',
                        from_name: 'arthur',
                        to_type:   'pg_restore',
                        to_url:    'postgres:///test2',
                        to_name:   'esther',
                        num_keep:  666)
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

    describe "POST /groups/:name/transfers/:id/actions/public-url" do
      let(:xfer)    { create(:transfer, group: @group) }
      let(:ttl)     { 5.minutes }
      let(:pub_url) { "https://example.com/my-transfer?secret=foo" }

      context "successful public-url call" do
        before do
          xfer.complete
          allow(Transferatu::Mediators::Transfers::PublicUrlor)
            .to receive(:run).with(ttl: ttl, transfer: xfer).and_return(pub_url)
          header "Content-Type", "application/json"
        end

        it "creates a public url for a to-gof3r transfer" do
          post "/groups/#{@group.name}/transfers/#{xfer.uuid}/actions/public-url",
               JSON.generate(ttl: ttl)
          expect(last_response.status).to eq(201)
        end
      end

      it "refuses to create a public url for unfinished transfer" do
        xfer.update(finished_at: nil, succeeded: nil)
        post "/groups/#{@group.name}/transfers/#{xfer.uuid}/actions/public-url",
          JSON.generate(ttl: ttl)
        expect(last_response.status).to eq(400)
        response = JSON.parse(last_response.body)
        expect(response['message']).to match(/for completed transfers/)
      end

      it "refuses to create a public url for failed transfer" do
        xfer.update(succeeded: false)
        post "/groups/#{@group.name}/transfers/#{xfer.uuid}/actions/public-url",
          JSON.generate(ttl: ttl)
        expect(last_response.status).to eq(400)
        response = JSON.parse(last_response.body)
        expect(response['message']).to match(/for completed transfers/)
      end

      it "refuses to create a public url for non-to-gof3r transfer" do
        xfer.update(to_type: 'pg_restore')
        post "/groups/#{@group.name}/transfers/#{xfer.uuid}/actions/public-url",
          JSON.generate(ttl: ttl)
        expect(last_response.status).to eq(400)
        response = JSON.parse(last_response.body)
        expect(response['message']).to match(/for backup transfers/)
      end
    end

    describe "POST /groups/:name/transfers/actions/cancel" do
      let(:xfer)    { create(:transfer, group: @group) }

      before do
        header "Content-Type", "application/json"
      end

      it "cancels a pending transfer" do
        post "/groups/#{@group.name}/transfers/#{xfer.uuid}/actions/cancel"
        expect(last_response.status).to eq(201)
      end

      it "cancels an in-progress transfer" do
        xfer.update(started_at: Time.now)
        post "/groups/#{@group.name}/transfers/#{xfer.uuid}/actions/cancel"
        expect(last_response.status).to eq(201)
      end

      it "refuses to cancel a completed transfer" do
        xfer.complete
        post "/groups/#{@group.name}/transfers/#{xfer.uuid}/actions/cancel"
        expect(last_response.status).to eq(400)
      end
    end
  end
end
