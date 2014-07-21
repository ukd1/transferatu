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
        @group = find_group(params[:group])
      end

      helpers do
        def find_group(name)
          group = current_user.groups_dataset.present.where(name: name).first
          if group.nil?
            raise Pliny::Errors::NotFound, "group #{name} does not exist"
          else
            group
          end
        end

        def find_transfer(group, id)
          xfer = if id =~ /\A\d+\z/
                   group.transfers_dataset.where(transfer_num: id.to_i)
                 else
                   group.transfers_dataset.where(uuid: id)
                 end.first
          if xfer.nil?
            raise Pliny::Errors::NotFound, "transfer #{id} for group #{group.name} does not exist"
          elsif xfer.deleted?
            raise Pliny::Errors::Gone, "transfer #{id} for group #{group.name} destroyed at #{xfer.deleted_at}"
          else
            xfer
          end
        end
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
        transfer = find_transfer(@group, params[:id])
        if params[:verbose]
          respond serialize(transfer, flavor: :verbose)
        else
          respond serialize(transfer)
        end
      end

      delete "/:id" do
        # This could go in a mediator, but there's no point for now
        # while this is so thin
        transfer = find_transfer(@group, params[:id])
        transfer.destroy
        respond serialize(transfer)
      end
    end
  end
end
