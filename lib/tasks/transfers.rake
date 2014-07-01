namespace :transfers do
  task :run do
    require "bundler"
    Bundler.require
    require_relative "../initializer"

    Transferatu::TransferSupervisor.run
  end
end
