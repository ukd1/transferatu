FactoryGirl.define do
  to_create { |instance| instance.save }

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
    logplex_token
    type "pg_dump:gof3r"
    group
    from_url
    to_url
  end

  factory :group, class: Transferatu::Group do
    user
    sequence(:name) { |i| "group-#{i}" }
  end

  factory :user, class: Transferatu::User do
    sequence(:name) { |i| "user-#{i}" }
  end

end
