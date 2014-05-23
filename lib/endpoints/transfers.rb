module Endpoints
  class Transfers < Base
    namespace "/transfers" do
      before do
        content_type :json
      end

      get do
        "[]"
      end

      post do
        status 201
        "{}"
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
