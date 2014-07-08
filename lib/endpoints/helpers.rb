module Transferatu
  module Endpoints
    module Authenticator
      attr_reader :current_user

      def authenticate
        # TODO: this authentication check is pretty crufty
        auth = Rack::Auth::Basic::Request.new(request.env)
        unless auth.provided? && auth.basic? && auth.credentials
          throw(:halt, [401, "Not Authorized\n"])
        end
        user, password = auth.credentials
        @current_user = Transferatu::User.where(name: user, deleted_at: nil).first
        unless @current_user && @current_user.password == password
          throw(:halt, [401, "Not Authorized\n"])
        end
      end
    end

    module Serializer
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def serialize_with(klass, flavor: :default)
          @serializer = klass.new(flavor)
        end

        def serializer
          @serializer
        end
      end

      def serialize(result)
        unless result.nil?
          self.class.serializer.serialize(result)
        end
      end
    end
  end
end
