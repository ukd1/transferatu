module Transferatu
  module Mediators::Groups
    class Creator < Mediators::Base
      def initialize(user: , name:, log_input_url: nil)
        @user = user
        @name = name
        @log_input_url = log_input_url
      end

      def call
        @user.add_group(name: @name, log_input_url: @log_input_url)
      end
    end
  end
end
