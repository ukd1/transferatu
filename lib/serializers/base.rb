module Transferatu
  module Serializers
    class Base
      @@structures = {}

      def self.structure(type, &blk)
        @@structures["#{self.name}::#{type}"] = blk
      end

      def initialize(type)
        @type = type
      end

      def serialize(object)
        serializer = @@structures["#{self.class.name}::#{@type}"]
        if object.is_a?(Array)
          object.map { |item| serializer.call(item) }
        else
          serializer.call(object)
        end
      end
    end
  end
end
