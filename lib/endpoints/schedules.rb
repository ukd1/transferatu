require_relative 'helpers'

module Transferatu::Endpoints
  class Schedules < Base
    include Serializer

    serialize_with Transferatu::Serializers::Schedule

    namespace "/groups/:group/schedules" do
      before do
        content_type :json, charset: 'utf-8'
        @group = current_user.groups_dataset.present.where(name: params[:group]).first
      end

      get do
        schedules = @group.schedules_dataset.present.all
        respond serialize(schedules)
      end

      post do
        schedule = Transferatu::Mediators::Schedules::Creator.run(
                   group: @group,
                   name: data["name"],
                   callback_url: data["callback_url"],
                   days: data["days"],
                   hour: data["hour"],
                   timezone: data["timezone"],
                   retain_weeks: data["retain_weeks"],
                   retain_months: data["retain_months"]
                 )
        respond serialize(schedule), status: 201
      end

      get "/:id" do
        schedule = @group.schedules_dataset.present.where(uuid: params[:id]).first
        respond serialize(schedule)
      end

      delete "/:id" do
        schedule = @group.schedules_dataset.present.where(uuid: params[:id]).first
        unless schedule.nil?
          schedule.destroy
        end
        respond serialize(schedule)
      end
    end
  end
end
