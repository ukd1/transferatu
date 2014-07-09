namespace :quiescence do
  task :enable, :mode do |t, args|
    mode = args.mode || 'soft'
    unless %w(hard soft).include? mode
      raise ArgumentError, "unknown mode: #{mode}; expected 'hard' or 'soft'"
    end

    require "bundler"
    Bundler.require
    require_relative "../initializer"

    Transferatu::AppStatus.quiesce
    if mode == 'hard'
      Transfer.present.in_progress.each { |t| t.cancel }
    end
  end

  task :disable do
    require "bundler"
    Bundler.require
    require_relative "../initializer"

    Transferatu::AppStatus.resume
  end
end
