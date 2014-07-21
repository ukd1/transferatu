module Transferatu
  module Endpoints
    module Authenticator
      attr_reader :current_user

      def authenticate
        auth = Rack::Auth::Basic::Request.new(request.env)
        unless auth.provided? && auth.basic? && auth.credentials
          raise Pliny::Errors::Unauthorized
        end
        user, password = auth.credentials
        @current_user = Transferatu::User.where(name: user, deleted_at: nil).first
        unless @current_user && @current_user.password == password
          raise Pliny::Errors::Unauthorized
        end
      end
    end

    module Serializer
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def serialize_with(klass)
          @serializer_class = klass
          @serializers = {}
        end

        def serializer(flavor)
          @serializers[flavor] ||= @serializer_class.new(flavor)
        end
      end

      def serialize(result, flavor: :default)
        unless result.nil?
          self.class.serializer(flavor).serialize(result)
        end
      end
    end
  end
end
