require "spec_helper"

describe Transferatu::Endpoints::Authenticator do
  let(:rack_env)     { double(:rack_env) }
  let(:rack_request) { double(:request, env: rack_env) }
  let(:rack_auth)    { double(:auth) }

  let!(:user1) { create(:user) }
  let!(:user2) { create(:user) }
  let!(:user3) { create(:user) }
  let(:auther) { Object.new.extend(Transferatu::Endpoints::Authenticator) }

  before do
    auther.stub(request: rack_request)
    Rack::Auth::Basic::Request.should_receive(:new)
      .with(rack_env).and_return(rack_auth)
  end

  it "finds the right user with the correct credentials" do
    rack_auth.stub(provided?: true, basic?: true, credentials: [ user1.name, user1.token ])
    auther.authenticate
    expect(auther.current_user.uuid).to eq(user1.uuid)
  end

  it "finds the right user even when two users have same token" do
    rack_auth.stub(provided?: true, basic?: true, credentials: [ user1.name, user1.token ])
    user2.update(token: user1.token)
    auther.authenticate
    expect(auther.current_user.uuid).to eq(user1.uuid)
  end

  it "throws 401 for a non-existent user" do
    rack_auth.stub(provided?: true, basic?: true, credentials: [ 'agnes', 'passw0rd' ])
    expect { auther.authenticate }.to throw_symbol(:halt)
  end

  it "throws 401 for a deleted user" do
    user1.update(deleted_at: Time.now)
    rack_auth.stub(provided?: true, basic?: true, credentials: [ user1.name, user1.token ])
    expect { auther.authenticate }.to throw_symbol(:halt)
  end

  it "throws 401 if credentials not provided" do
    rack_auth.stub(provided?: false, basic?: true, credentials: nil)
    expect { auther.authenticate }.to throw_symbol(:halt)
  end

  it "throws 401 for auth other than basic auth" do
    rack_auth.stub(provided?: false, basic?: false, credentials: [ user1.name, user1.token ])
    expect { auther.authenticate }.to throw_symbol(:halt)
  end
end
