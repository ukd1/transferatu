require "pliny/config_helpers"

# Access all config keys like the following:
#
#     Config.database_url
#
# Each accessor corresponds directly to an ENV key, which has the same name
# except upcased, i.e. `DATABASE_URL`.
#
# Note that *all* keys will come out as strings even if the override was a
# different type. Make sure to typecast any values that need to be something
# else (i.e. `.to_i`).
module Config
  extend Pliny::ConfigHelpers

  mandatory \
    :database_url

  optional \
    :placeholder

  override \
    port:             5000,
    puma_max_threads: 16,
    puma_min_threads: 1,
    puma_workers:     3,
    rack_env:         "development"
end
