Sequel.migration do
  up do
    alter_table(:groups) do
      add_column :logplex_token, :text
    end
    execute <<-EOF
WITH tokens AS (
  SELECT
    DISTINCT ON (group_id) group_id, logplex_token
  FROM
    transfers
  ORDER BY
    group_id, created_at DESC
)
UPDATE
  groups
SET
  logplex_token = tokens.logplex_token
FROM
  tokens
WHERE
  tokens.group_id = groups.uuid
EOF
    alter_table(:transfers) do
      drop_column :logplex_token
    end
  end

  down do
    alter_table(:transfers) do
      add_column :logplex_token, :text
    end
    execute <<-EOF
UPDATE
  transfers
SET
  logplex_token = groups.logplex_token
FROM
  groups
WHERE
  group_id = groups.uuid
EOF
    alter_table(:groups) do
      drop_column :logplex_token
    end
  end
end
