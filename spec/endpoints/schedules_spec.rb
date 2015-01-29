require "spec_helper"

module Transferatu::Endpoints
  describe Schedules do
    include Rack::Test::Methods

    def app
      Schedules
    end

    before do
      @user = create(:user)
      @group = create(:group, user: @user)
      Transferatu::RequestStore.current_user = @user
    end

    describe "GET /groups/:name/schedules" do
      it "succeeds" do
        get "/groups/#{@group.name}/schedules"
        expect(last_response.status).to eq(200)
      end
    end

    describe "GET /groups/:name/schedules/:id" do
      let(:schedule) { create(:schedule, group: @group) }

      it "succeeds" do
        get "/groups/#{@group.name}/schedules/#{schedule.uuid}"
        expect(last_response.status).to eq(200)
      end
    end

    describe "POST /groups/:name/schedules" do
      before do
        header "Content-Type", "application/json"
      end
      it "succeeds" do
        post "/groups/#{@group.name}/schedules", JSON.generate(
                                                 name: 'my-schedule',
                                                 callback_url: "https://example.com/#{@group.name}/schedules/my-schedule",
                                                 hour: 23,
                                                 days: ['Sunday', 'Tuesday', 'Friday'],
                                                 timezone: 'America/Los_Angeles'
                                               )
        expect(last_response.status).to eq(201)
      end

      it "accepts optional retention parameters" do
        post "/groups/#{@group.name}/schedules", JSON.generate(
                                                 name: 'my-schedule',
                                                 callback_url: "https://example.com/#{@group.name}/schedules/my-schedule",
                                                 hour: 23,
                                                 days: ['Sunday', 'Tuesday', 'Friday'],
                                                 timezone: 'America/Los_Angeles',
                                                 retain_weeks: 5,
                                                 retain_months: 3
                                               )
        expect(last_response.status).to eq(201)
      end
    end

  end
end
