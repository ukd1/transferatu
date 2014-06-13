module Initializer
  def self.run
    require_config
    require_lib
    require_initializers
    require_models
    require_workers
  end

  def self.require_config
    require_relative "../config/config"
  end

  def self.initialize_database
    Sequel.connect(Config.database_url, max_connections: Config.db_pool)
    db = Sequel::DATABASES.first
    db.extension :pg_json
  end

  def self.require_lib
    require! %w(
      lib/endpoints/base
      lib/endpoints/**/*
      lib/mediators/base
      lib/mediators/**/*
      lib/models/**/*
      lib/routes
      lib/serializers/base
      lib/serializers/**/*
    )
  end

  def self.require_models
    require! %w(
      lib/models/**/*
    )
  end

  def self.require_workers
    require! %w(
      lib/workers/**/*
    )
  end

  def self.require_initializers
    Pliny::Utils.require_glob("#{Config.root}/config/initializers/*.rb")
  end

  def self.require!(globs)
    globs = [globs] unless globs.is_a?(Array)
    globs.each do |f|
      Pliny::Utils.require_glob("#{Config.root}/#{f}.rb")
    end
  end
end

Initializer.run
