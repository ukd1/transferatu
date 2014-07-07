Sequel.connect(Config.database_url, max_connections: Config.db_pool)
db = Sequel::DATABASES.first
db.extension :pg_json
db.extension :pg_array
