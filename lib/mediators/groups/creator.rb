module Transferatu
  module Mediators::Groups
    class Creator < Mediators::Base
      def initialize(user: , name:, logplex_token: nil)
        @user = user
        @name = name
        @logplex_token = logplex_token
      end

      def call
        @user.add_group(name: @name, logplex_token: @logplex_token)
      end
    end
  end
end
