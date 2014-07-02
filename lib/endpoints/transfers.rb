module Transferatu::Endpoints
  class Transfers < Base
    include Authenticator

    def serializer
      @serializer ||= Transferatu::Serializers::Transfer.new(:default)
    end

    def serialize(transfer)
      serializer.serialize(transfer)
    end

    def self.schema
      @@schema ||= File.read("docs/schema.json")
    end

    use Committee::Middleware::RequestValidation,
        schema: schema, strict: true

    helpers do
      def data
        env["committee.params"]
      end
    end

    namespace "/groups/:group/transfers" do
      before do
        content_type :json, charset: 'utf-8'
        authenticate
        @group = Transferatu::Group.find(user: current_user, name: params[:group])
      end

      get do
        transfers = Transferatu::Transfer.where(deleted_at: nil, group: @group).all
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
        transfer = Transferatu::Transfer[uuid: params[:id], group: @group]
        respond serialize(transfer)
      end

      delete "/:id" do |id|
        # This could go in a mediator, but there's no point for now
        # while this is so thin
        transfer = Transferatu::Transfer[uuid: params[:id], group: @group]
        unless transfer.nil?
          transfer.destroy
        end
        respond serialize(transfer)
      end
    end
  end
end
