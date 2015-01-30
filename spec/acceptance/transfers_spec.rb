require "spec_helper"

module Transferatu
  describe Endpoints::Transfers do
    include Committee::Test::Methods
    include Rack::Test::Methods

    def app
      Routes
    end

    let(:request_data) do
      { from_url: 'postgres:///test1', from_type: 'pg_dump', from_name: 'ezra',
        to_url: 'postgres:///test2', to_type: 'pg_restore', to_name: 'george' }
    end

    before do
      @password = 'hunter2'
      @user = create(:user, password: @password)
      @group = create(:group, user: @user)
    end

    describe "when unauthenticated" do
      it "rejects requests" do
        get "/groups/#{@group.name}/transfers"
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

      it "GET /groups/:name/transfers" do
        get "/groups/#{@group.name}/transfers"
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq([])
      end

      describe "POST /groups/:name/transfers" do
        it "creates a new transfer" do
          post "/groups/#{@group.name}/transfers", request_data
          expect(last_response.status).to eq(201)
          response = JSON.parse(last_response.body)
          request_data.keys.each do |key|
            expect(response[key.to_s]).to eq request_data[key]
          end
          xfer_id = response["uuid"]
          expect(xfer_id).to_not be_nil
          xfer = Transferatu::Transfer[xfer_id]
          request_data.keys.each do |key|
            expect(xfer.public_send(key)).to eq request_data[key]
          end
        end

        it "takes an optional num_keep argument" do
          num_keep = 23
          post "/groups/#{@group.name}/transfers", request_data.merge(num_keep: num_keep)
          expect(last_response.status).to eq(201)
          response = JSON.parse(last_response.body)
          expect(response['num_keep']).to eq num_keep

          xfer_id = response["uuid"]
          expect(xfer_id).to_not be_nil
          xfer = Transferatu::Transfer[xfer_id]
          expect(xfer.num_keep).to eq num_keep
        end

        it "updates the group's log_input_url if provided" do
          new_log_url = "https://example.com/log-here"
          post "/groups/#{@group.name}/transfers", request_data
            .merge(log_input_url: new_log_url)
          expect(last_response.status).to eq(201)
          response = JSON.parse(last_response.body)
          xfer_id = response["uuid"]
          expect(xfer_id).to_not be_nil
          xfer = Transferatu::Transfer[xfer_id]
          expect(xfer.group.log_input_url).to eq(new_log_url)
        end
      end

      it "GET /groups/:name/transfers/:id" do
        xfer = create(:transfer, group: @group)
        get "/groups/#{@group.name}/transfers/#{xfer.uuid}"
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        %i(from_url from_name from_type to_url to_name to_type).each do |field|
          expect(response[field.to_s]).to eq(xfer.public_send(field))
        end
      end

      it "DELETE /groups/:name/transfers/:id" do
        xfer = create(:transfer, group: @group)
        before_deletion = Time.now
        delete "/groups/#{@group.name}/transfers/#{xfer.uuid}"
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        %i(from_url from_name from_type to_url to_name to_type).each do |field|
          expect(response[field.to_s]).to eq(xfer.public_send(field))
        end
        xfer.reload
        expect(xfer.deleted?).to be true
        expect(xfer.deleted_at).to be > before_deletion
        expect(xfer.deleted_at).to be < Time.now
      end

      it "POST /groups/:name/transfers/:id/actions/public-url" do
        pub_url = "https://example.com/transfers/123?signature=trustme"
        ttl = 5.minutes
        xfer = create(:transfer, group: @group)
        xfer.complete
        allow(Transferatu::Mediators::Transfers::PublicUrlor)
          .to receive(:run).and_return(pub_url)

        before = Time.now
        post "/groups/#{@group.name}/transfers/#{xfer.uuid}/actions/public-url", { ttl: ttl }
        after = Time.now

        expect(last_response.status).to eq(201)
        response = JSON.parse(last_response.body)
        expires_at = Time.parse(response["expires_at"])
        # N.B.: the expiration time will be truncated by JSON
        # timestamp formatting, so it could appear to preceed the
        # before timestamp
        expect(expires_at).to be_within(1.second).of(before + ttl)
        expect(expires_at).to be <= (after + ttl)
        expect(response["url"]).to eq(pub_url)
      end

      it "POST /groups/:name/transfers/:id/actions/cancel" do
        xfer = create(:transfer, group: @group)

        before = Time.now
        post "/groups/#{@group.name}/transfers/#{xfer.uuid}/actions/cancel"
        after = Time.now

        expect(last_response.status).to eq(201)
        response = JSON.parse(last_response.body)
        canceled_at = Time.parse(response["canceled_at"])
        expect(canceled_at).to be_within(1.second).of(before)
        expect(canceled_at).to be <= after

        expect(xfer.canceled?).to be true
      end
    end
  end
end
