require_relative 'helpers'

module Transferatu::Endpoints
  class Transfers < Base
    include Authenticator
    include Serializer

    serialize_with Transferatu::Serializers::Transfer

    namespace "/groups/:group/transfers" do
      before do
        content_type :json, charset: 'utf-8'
        authenticate
        @group = current_user.groups_dataset.present.where(name: params[:group]).first
      end

      get do
        transfers = @group.transfers_dataset.present.all
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
        transfer = @group.transfers_dataset.present.where(uuid: params[:id]).first
        respond serialize(transfer)
      end

      delete "/:id" do |id|
        # This could go in a mediator, but there's no point for now
        # while this is so thin
        transfer = @group.transfers_dataset.present.where(uuid: params[:id]).first
        unless transfer.nil?
          transfer.destroy
        end
        respond serialize(transfer)
      end
    end
  end
end
