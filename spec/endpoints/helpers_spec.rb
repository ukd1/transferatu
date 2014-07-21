require "spec_helper"

describe Transferatu::Endpoints::Authenticator do
  let(:rack_env)     { double(:rack_env) }
  let(:rack_request) { double(:request, env: rack_env) }
  let(:rack_auth)    { double(:auth) }

  let(:pwd1) { 'passw0rd' }
  let(:pwd2) { 'mr. fluffy' }
  let(:pwd3) { 'super-secret' }

  let!(:user1) { create(:user, password: pwd1) }
  let!(:user2) { create(:user, password: pwd2) }
  let!(:user3) { create(:user, password: pwd3) }
  let(:auther) { Object.new.extend(Transferatu::Endpoints::Authenticator) }

  before do
    auther.stub(request: rack_request)
    Rack::Auth::Basic::Request.should_receive(:new)
      .with(rack_env).and_return(rack_auth)
  end

  it "finds the right user with the correct credentials" do
    rack_auth.stub(provided?: true, basic?: true, credentials: [ user1.name, pwd1 ])
    auther.authenticate
    expect(auther.current_user.uuid).to eq(user1.uuid)
  end

  it "finds the right user even when two users have same password" do
    rack_auth.stub(provided?: true, basic?: true, credentials: [ user1.name, pwd1 ])
    user2.password = pwd1
    auther.authenticate
    expect(auther.current_user.uuid).to eq(user1.uuid)
  end

  it "raises Unauthorized for a non-existent user" do
    rack_auth.stub(provided?: true, basic?: true, credentials: [ 'agnes', 'password123' ])
    expect { auther.authenticate }.to raise_error(Pliny::Errors::Unauthorized)
  end

  it "raises Unauthorized for a deleted user" do
    user1.update(deleted_at: Time.now)
    rack_auth.stub(provided?: true, basic?: true, credentials: [ user1.name, pwd1 ])
    expect { auther.authenticate }.to raise_error(Pliny::Errors::Unauthorized)
  end

  it "raises Unauthorized if credentials not provided" do
    rack_auth.stub(provided?: false, basic?: true, credentials: nil)
    expect { auther.authenticate }.to raise_error(Pliny::Errors::Unauthorized)
  end

  it "raises Unauthorized for auth other than basic auth" do
    rack_auth.stub(provided?: false, basic?: false, credentials: [ user1.name, pwd1 ])
    expect { auther.authenticate }.to raise_error(Pliny::Errors::Unauthorized)
  end
end

describe Transferatu::Endpoints::Serializer do
  class FakeSerializer; end
  class SerializerClient
    include Transferatu::Endpoints::Serializer

    serialize_with FakeSerializer

    def invoke_serializer(o)
      serialize(o)
    end

    def invoke_custom_serializer(o)
      serialize(o, flavor: :custom)
    end
  end
  let(:srlzr_class)    { FakeSerializer }
  let(:srlzr_instance) { double(:serializer) }
  let(:some_object)    { double(:some_object) }
  let(:client)         { SerializerClient.new }

  it "invokes the associated serializer" do
    srlzr_class.should_receive(:new).with(:default).and_return(srlzr_instance)
    srlzr_instance.should_receive(:serialize).with(some_object)
    client.invoke_serializer(some_object)
  end

  it "supports custom serialization flavors" do
    srlzr_class.should_receive(:new).with(:custom).and_return(srlzr_instance)
    srlzr_instance.should_receive(:serialize).with(some_object)
    client.invoke_custom_serializer(some_object)
  end
end
