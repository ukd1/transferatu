require_relative 'helpers'

module Transferatu::Endpoints
  class Transfers < Base
    include Authenticator

    def serializer
      @serializer ||= Transferatu::Serializers::Transfer.new(:default)
    end

    def serialize(transfer)
      serializer.serialize(transfer)
    end

    namespace "/groups/:group/transfers" do
      before do
        content_type :json, charset: 'utf-8'
        authenticate
        @group = Transferatu::Group.present.where(user: current_user, name: params[:group]).first
      end

      get do
        transfers = Transferatu::Transfer.present.where(group: @group).all
        respond serialize(transfers)
      end

      post do
        transfer = Transferatu::Mediators::Transfers::Creator.run(
                   group: @group,
                   type: data["type"],
                   from_url: data["from_url"],
                   to_url: data["to_url"],
                   options: data["options"] || {}
                 )
        respond serialize(transfer), status: 201
      end

      get "/:id" do
        transfer = Transferatu::Transfer.present.where(uuid: params[:id], group: @group).first
        respond serialize(transfer)
      end

      delete "/:id" do |id|
        # This could go in a mediator, but there's no point for now
        # while this is so thin
        transfer = Transferatu::Transfer.present.where(uuid: params[:id], group: @group).first
        unless transfer.nil?
          transfer.destroy
        end
        respond serialize(transfer)
      end
    end
  end
end
