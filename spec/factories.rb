FactoryGirl.define do
  to_create { |instance| instance.save }

  sequence :group do |i|
    "group-#{i}"
  end

  sequence :logplex_token do |i|
    "t.logplex-token-#{i}"
  end

  sequence :from_url do |i|
    "postgres://example.com/db-#{i}"
  end

  sequence :to_url do |i|
    "https://bucket.s3.amazonaws.com/key-#{i}"
  end

  factory :transfer, class: Transferatu::Transfer do
    user_id SecureRandom.uuid
    group
    logplex_token
    type "pg_dump:gof3r"
    from_url
    to_url
  end
end
