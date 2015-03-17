require "spec_helper"

module Transferatu
  describe Endpoints::Schedules do
    include Committee::Test::Methods
    include Rack::Test::Methods

    def app
      Routes
    end

    before do
      @password = 'hunter2'
      @user = create(:user, password: @password)
      @group = create(:group, user: @user)
    end

    let(:request_data) do
      { name: 'my-schedule',
        callback_url: "https://example.com/#{@group.name}/schedules/my-schedule",
        hour: 23,
        days: ['Sunday', 'Tuesday', 'Friday'],
        timezone: 'America/Los_Angeles',
        retain_weeks: 6,
        retain_months: 3 }
    end

    describe "when unauthenticated" do
      it "rejects requests" do
        get "/groups/#{@group.name}/schedules"
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

      it "GET /groups/:name/schedules" do
        get "/groups/#{@group.name}/schedules"
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq([])
      end

      it "POST /groups/:name/schedules" do
        post "/groups/#{@group.name}/schedules", request_data
        expect(last_response.status).to eq(201)
        response = JSON.parse(last_response.body)
        request_data.keys.reject { |k| k == :callback_url }.each do |key|
          expect(response[key.to_s]).to eq request_data[key]
        end
        sched_id = response["uuid"]
        expect(sched_id).to_not be_nil
        sched = Transferatu::Schedule[sched_id]
        request_data.keys.reject { |k| k == :days }.each do |key|
          expect(sched.public_send(key)).to eq request_data[key]
        end
        expect(sched.dows).to eq(request_data[:days].map { |d| Date::DAYNAMES.index(d) })
      end

      it "PUT /groups/:name/schedules/:id" do
        verify_response = ->(data, expected_status: 200, expected_uuid: nil) do
          expect(last_response.status).to eq(expected_status)
          response = JSON.parse(last_response.body)
          data.keys.reject { |k| k == :callback_url }.each do |key|
            expect(response[key.to_s]).to eq data[key]
          end
          expect(response["uuid"]).not_to be_nil
          expect(response["uuid"]).to eq(expected_uuid) unless expected_uuid.nil?
          sched = Schedule[response["uuid"]]
          data.keys.reject { |k| k == :days }.each do |key|
            expect(sched.public_send(key)).to eq data[key]
          end
          expect(sched.dows).to eq(data[:days].map { |d| Date::DAYNAMES.index(d) })
        end
        put "/groups/#{@group.name}/schedules/#{request_data[:name]}", request_data
        verify_response.call(request_data, expected_status: 201)
        updates = { name: 'my-awesome-schedule',
                    callback_url: "https://example.com/#{@group.name}/schedules/foo",
                    hour: 19,
                    days: ['Sunday', 'Friday'],
                    timezone: 'America/Chicago',
                    retain_weeks: 12,
                    retain_months: 19 }
        expected_uuid = Schedule.first.uuid
        put "/groups/#{@group.name}/schedules/#{request_data[:name]}", updates
        verify_response.call(updates)
      end

      context "it allows replacing a deleted schedule" do
        it "PUT /groups/:name/schedules/:id" do
          sched = create(:schedule, group: @group)
          sched.delete

          put "/groups/#{@group.name}/schedules/#{request_data[:name]}", request_data
          expect(last_response.status).to eq(201)
          response = JSON.parse(last_response.body)
          request_data.keys.reject { |k| k == :callback_url }.each do |key|
            expect(response[key.to_s]).to eq request_data[key]
          end
        end
      end

      it "GET /groups/:name/schedules/:id" do
        sched = create(:schedule, group: @group)
        get "/groups/#{@group.name}/schedules/#{sched.uuid}"
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        %i(name hour timezone).each do |field|
          expect(response[field.to_s]).to eq(sched.public_send(field))
        end
        expect(response["days"]).to eq(sched.dows.map { |d| Date::DAYNAMES[d] })
      end

      it "DELETE /groups/:name/schedules/:id" do
        sched = create(:schedule, group: @group)
        before_deletion = Time.now
        delete "/groups/#{@group.name}/schedules/#{sched.uuid}"
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        %i(name hour timezone).each do |field|
          expect(response[field.to_s]).to eq(sched.public_send(field))
        end
        expect(response["days"]).to eq(sched.dows.map { |d| Date::DAYNAMES[d] })
        sched.reload
        expect(sched.deleted?).to be true
        expect(sched.deleted_at).to be > before_deletion
        expect(sched.deleted_at).to be < Time.now
      end
    end
  end
end
