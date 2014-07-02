require_relative 'helpers'

module Transferatu::Endpoints
  class Groups < Base
    include Authenticator

    def serializer
      @serializer ||= Transferatu::Serializers::Group.new(:default)
    end

    def serialize(transfer)
      serializer.serialize(transfer)
    end

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
        group = Transferatu::Mediators::Groups::Creator.run(
                user: current_user,
                name: data["name"]
              )
        respond serialize(group), status: 201
      end

      get "/:id" do
        group = current_user.groups_dataset.present.where(uuid: params[:id]).first
        respond serialize(group)
      end

      delete "/:id" do |id|
        group = current_user.groups_dataset.present.where(uuid: params[:id]).first
        unless group.nil?
          group.destroy
        end
        respond serialize(group)
      end
    end
  end
end
