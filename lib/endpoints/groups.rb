require_relative 'helpers'

module Transferatu::Endpoints
  class Groups < Base
    include Authenticator
    include Serializer

    serialize_with Transferatu::Serializers::Group

    namespace "/groups" do
      before do
        content_type :json, charset: 'utf-8'
        authenticate
      end

      get do
        groups = current_user.groups_dataset.present.all
        respond serialize(groups)
      end

      post do
        begin
          group = Transferatu::Mediators::Groups::Creator.run(
                  user: current_user,
                  name: data["name"]
                )
          respond serialize(group), status: 201
        rescue Sequel::UniqueConstraintViolation => e
          raise Pliny::Errors::Conflict, "group #{data["name"]} already exists"
        end
      end

      get "/:name" do
        group = current_user.groups_dataset.present.where(name: params[:name]).first
        respond serialize(group)
      end

      delete "/:name" do |id|
        group = current_user.groups_dataset.present.where(name: params[:name]).first
        unless group.nil?
          group.destroy
        end
        respond serialize(group)
      end
    end
  end
end
