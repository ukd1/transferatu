require_relative 'helpers'

module Transferatu::Endpoints
  class Schedules < Base
    include Serializer
    include GroupFinder

    serialize_with Transferatu::Serializers::Schedule

    namespace "/groups/:group/schedules" do
      before do
        content_type :json, charset: 'utf-8'
        @group = find_group(params[:group])
      end

      helpers do
        def with_schedule(id)
          schedule = @group.schedules_dataset.present.where(uuid: id).first
          if schedule.nil?
            raise Pliny::Errors::NotFound, "schedule #{id} does not exist"
          else
            yield(schedule)
          end
        end
      end

      get do
        schedules = @group.schedules_dataset.present.all
        respond serialize(schedules)
      end

      post do
        schedule = Transferatu::Mediators::Schedules::Creator
          .run(group: @group,
               name: data["name"],
               callback_url: data["callback_url"],
               days: data["days"],
               hour: data["hour"],
               timezone: data["timezone"],
               retain_weeks: data["retain_weeks"],
               retain_months: data["retain_months"])
        respond serialize(schedule), status: 201
      end

      put "/:id" do
        with_schedule(params[:id]) do |s|
          schedule = Transferatu::Mediators::Schedules::Updator
            .run(schedule: s,
                 name: data["name"],
                 callback_url: data["callback_url"],
                 days: data["days"],
                 hour: data["hour"],
                 timezone: data["timezone"],
                 retain_weeks: data["retain_weeks"],
                 retain_months: data["retain_months"])
          respond serialize(schedule), status: 200
        end
      end

      get "/:id" do
        with_schedule(params[:id]) do |s|
          respond serialize(s)
        end
      end

      delete "/:id" do
        with_schedule(params[:id]) do |s|
          s.destroy
          respond serialize(s)
        end
      end
    end
  end
end
