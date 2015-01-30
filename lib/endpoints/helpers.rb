module Transferatu
  module Endpoints
    module GroupFinder
      def find_group(name)
        group = current_user.groups_dataset.present.where(name: name).first
        if group.nil?
          raise Pliny::Errors::NotFound, "group #{name} does not exist"
        else
          group
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
