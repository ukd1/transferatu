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
      def group
        Transferatu::Group.find(user: current_user, name: data["group"]["name"])
      end
    end

    namespace "/transfers" do
      before do
        content_type :json
        authenticate
      end

      get do
        "[]"
      end

      post do
        transfer = Transferatu::Mediators::Transfers::Creator.run(
                   group: group,
                   type: data["type"],
                   from_url: data["from_url"],
                   to_url: data["to_url"],
                   options: data["options"] || {}
                 )
        status 201
        respond serialize(transfer)
      end

      get "/:id" do
        "{}"
      end

      patch "/:id" do |id|
        "{}"
      end

      delete "/:id" do |id|
        "{}"
      end
    end
  end
end
