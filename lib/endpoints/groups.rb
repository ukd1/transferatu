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
        status 201
        "{}"
      end

      get "/:id" do
        "{}"
      end

      delete "/:id" do |id|
        "{}"
      end
    end
  end
end
