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
                   from_type: data["from_type"],
                   from_url: data["from_url"],
                   from_name: data["from_name"],
                   to_type: data["to_type"],
                   to_url: data["to_url"],
                   to_name: data["to_name"],
                   options: data["options"] || {}
                 )
        respond serialize(transfer), status: 201
      end

      get "/:id" do
        id = params[:id]
        transfer = if id =~ /\A\d+\z/
                     @group.transfers_dataset.present.where(transfer_num: id.to_i).first
                   else
                     @group.transfers_dataset.present.where(uuid: id).first
                   end
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
