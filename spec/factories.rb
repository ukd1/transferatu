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

  sequence :timezone do |i|
    zones = %w(America/Los_Angeles America/New_York Europe/Paris Asia/Hong_Kong)
    zones.at(i % zones.length)
  end

  factory :transfer, class: Transferatu::Transfer do
    logplex_token
    from_type "pg_dump"
    to_type "gof3r"
    group
    from_url
    to_url
  end

  factory :group, class: Transferatu::Group do
    user
    sequence(:name) { |i| "group-#{i}" }
  end

  factory :user, class: Transferatu::User do
    sequence(:name)          { |i| "user-#{i}" }
    sequence(:token)         { |i| "super-secret-#{i}" }
    sequence(:password_hash) { |i| "also-secret-#{i}" }
  end

  factory :schedule, class: Transferatu::Schedule do
    group
    sequence(:name)         { |i| "schedule-#{i}" }
    sequence(:callback_url) { |i| "https://example.com/transferatu/schedules/group-#{i}" }
    sequence(:hour)         { |i| i % 24 }
    # an arbitrary but not random set of days to run
    sequence(:dows)         { |i| (0..6).reject { |j| i % (j + 1) < 1 }.each_slice(4).first }
    timezone
  end
end
