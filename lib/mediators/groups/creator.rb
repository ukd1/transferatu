module Transferatu
  module Mediators::Groups
    class Creator < Mediators::Base
      def initialize(user: , name:, log_input_url:, backup_limit: 7)
        @user = user
        @name = name
        @log_input_url = log_input_url
        @backup_limit = backup_limit
      end

      def call
        @user.add_group(name: @name,
                        log_input_url: @log_input_url,
                        backup_limit: @backup_limit)
      rescue Sequel::UniqueConstraintViolation => e
        # allow "undelete" if a user is trying to create the "same"
        # group as an old, deleted one
        group = @user.groups_dataset.where(name: @name).first
        if group.deleted?
          group.update(deleted_at: nil,
                       log_input_url: @log_input_url,
                       backup_limit: @backup_limit)
          group
        else
          raise
        end
      end
    end
  end
end
