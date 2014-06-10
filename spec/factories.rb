FactoryGirl.define do
  to_create { |instance| instance.save }

  sequence :group do |i|
    "group-#{i}"
  end

  sequence :logplex_token do |i|
    "t.logplex-token-#{i}"
  end
  
  factory :transfer, class: Transferatu::Transfer do
    user_id SecureRandom.uuid
    group
    logplex_token
    type "pg_dump:gof3r"
  end
end

