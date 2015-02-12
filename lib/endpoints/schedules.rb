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
        def find_schedule(id)
          # if the id doesn't look like a uuid, don't submit it since postgres will freak out
          is_uuid = id && id.match(/[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}/)
          dataset = @group.schedules_dataset.present
          if is_uuid
            dataset = dataset.where(Sequel.|({uuid: id}, {name: id}))
          else
            dataset = dataset.where(name: id)
          end
          dataset.first
        end

        def with_schedule(id)
          schedule = find_schedule(id)
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
        begin
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
        rescue ArgumentError => e
          raise Pliny::Errors::BadRequest, e.message
        rescue Sequel::UniqueConstraintViolation
          existing = find_schedule(data['name'])
          respond serialize(existing), status: 409
        end
      end

      put "/:id" do
        begin
          sched = find_schedule(params[:id])
          opts = { name: data["name"],
                   callback_url: data["callback_url"],
                   days: data["days"],
                   hour: data["hour"],
                   timezone: data["timezone"],
                   retain_weeks: data["retain_weeks"],
                   retain_months: data["retain_months"] }
          if sched
            schedule = Transferatu::Mediators::Schedules::Updator
              .run(opts.merge(schedule: sched))
            respond serialize(schedule), status: 200
          else
            schedule = Transferatu::Mediators::Schedules::Creator
              .run(opts.merge(group: @group))
            respond serialize(schedule), status: 201
          end
        rescue ArgumentError => e
          raise Pliny::Errors::BadRequest, e.message
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
