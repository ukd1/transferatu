namespace :transfers do
  task :run do
    require "../initializer"
    Transferatu::TransferSupervisor.run
  end
end
