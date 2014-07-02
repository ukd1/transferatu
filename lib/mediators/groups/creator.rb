module Transferatu
  module Mediators::Groups
    class Creator < Mediators::Base
      def initialize(user: , name:)
        @user = user
        @name = name
      end

      def call
        @user.add_group(name: @name)
      end
    end
  end
end
