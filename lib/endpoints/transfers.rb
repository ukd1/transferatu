require_relative 'helpers'

module Transferatu::Endpoints
  class Transfers < Base
    include Serializer
    include GroupFinder

    serialize_with Transferatu::Serializers::Transfer

    namespace "/groups/:group/transfers" do
      before do
        content_type :json, charset: 'utf-8'
        @group = find_group(params[:group])
      end

      helpers do
        def find_transfer(group, id)
          xfer = if id =~ /\A\d+\z/
                   group.transfers_dataset.where(transfer_num: id.to_i)
                 else
                   group.transfers_dataset.where(uuid: id)
                 end.first
          if xfer.nil?
            raise Pliny::Errors::NotFound,
              "transfer #{id} for group #{group.name} does not exist"
          elsif xfer.deleted?
            raise Pliny::Errors::Gone,
              "transfer #{id} for group #{group.name} destroyed at #{xfer.deleted_at}"
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
        log_input_url = data.delete("log_input_url")
        unless log_input_url.nil?
          @group.update(log_input_url: log_input_url)
        end

        transfer = Transferatu::Mediators::Transfers::Creator
          .run(group: @group,
               from_type: data["from_type"],
               from_url: data["from_url"],
               from_name: data["from_name"],
               to_type: data["to_type"],
               to_url: data["to_url"],
               to_name: data["to_name"],
               options: data["options"] || {},
               num_keep: data["num_keep"])
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

      post "/:id/actions/public-url" do
        transfer = find_transfer(@group, params[:id])
        ttl = if data.has_key? 'ttl'
                data["ttl"].to_i
              else
                10.minutes
              end
        # Technically we'll have a few seconds longer, but the
        # underlying API takes a TTL too, and not a duration, so
        # there's no easy way to get around that.
        expires_at = Time.now + ttl
        url = Transferatu::Mediators::Transfers::PublicUrlor
          .run(transfer: transfer, ttl: ttl)
        # TODO: figure out how this fits in with proper serialization
        respond({ expires_at: expires_at, url: url }, status: 201)
      end

      post "/:id/actions/cancel" do
        # Here we can digress into a discussion on proper REST
        # semantics et cetera, but basically we want the cancellation
        # to reflect when we actually perform it here, versus
        # accepting an arbitrary canceled_at from the user. There may
        # be better ways to skin this cat.
        transfer = find_transfer(@group, params[:id])
        begin
          Transferatu::Mediators::Transfers::Cancelor.run(transfer: transfer)
          respond({ canceled_at: transfer.canceled_at }, status: 201)
        rescue StandardError => e
          raise Pliny::Errors::BadRequest, e.message
        end
      end
    end
  end
end
