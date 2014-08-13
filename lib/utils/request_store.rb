module Transferatu
  module RequestStore
    def self.clear!
      Thread.current[:request_store] = {}
    end

    def self.seed(env)
      store[:request_id] =
        env["REQUEST_IDS"] ? env["REQUEST_IDS"].join(",") : nil

      # a global context that evolves over the lifetime of the request, and is
      # used to tag all log messages that it produces
      store[:log_context] = {
        request_id: store[:request_id]
      }
    end

    def self.current_user=(value)
      store[:current_user] = value
    end

    def self.current_user
      store[:current_user]
    end

    private

    def self.store
      Thread.current[:request_store] ||= {}
    end
  end
end
