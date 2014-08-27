require "spec_helper"

module Transferatu::Middleware
  describe Authenticator do
    let(:app)       { double(:app) }
    let(:rack_env)  { double(:rack_env) }
    let(:rack_auth) { double(:auth) }

    let(:pwd1) { 'passw0rd' }
    let(:pwd2) { 'mr. fluffy' }
    let(:pwd3) { 'super-secret' }

    let!(:user1) { create(:user, password: pwd1) }
    let!(:user2) { create(:user, password: pwd2) }
    let!(:user3) { create(:user, password: pwd3) }

    let(:store)  { Struct.new(:current_user).new }
    let(:auther) { Authenticator.new(app, store: store) }

    describe "#call" do
      before do
        expect(Rack::Auth::Basic::Request).to receive(:new)
          .with(rack_env).and_return(rack_auth)
      end

      it "raises Unauthorized if no credentials are provided" do
        allow(rack_auth).to receive_messages(provided?: false, basic?: true, credentials: nil)
        expect { auther.call(rack_env) }.to raise_error(Pliny::Errors::Unauthorized)
      end

      it "raises Unauthorized when incorrect credentials are provided" do
        allow(rack_auth).to receive_messages(provided?: true, basic?: true, credentials: [ user1.name, pwd2 ])
        expect { auther.call(rack_env) }.to raise_error(Pliny::Errors::Unauthorized)
      end

      it "raises Unauthorized when credentials of a non-existent user are provided" do
        allow(rack_auth).to receive_messages(provided?: true, basic?: true, credentials: [ 'agnes', 'password123' ])
        expect { auther.call(rack_env) }.to raise_error(Pliny::Errors::Unauthorized)
      end

      it "raises Unauthorized when credentials of a deleted user are provided" do
        user1.update(deleted_at: Time.now)
        allow(rack_auth).to receive_messages(provided?: true, basic?: true, credentials: [ user1.name, pwd1 ])
        expect { auther.call(rack_env) }.to raise_error(Pliny::Errors::Unauthorized)
      end

      it "raises Unauthorized for auth other than basic auth" do
        allow(rack_auth).to receive_messages(provided?: false, basic?: false, credentials: [ user1.name, pwd1 ])
        expect { auther.call(rack_env) }.to raise_error(Pliny::Errors::Unauthorized)
      end

      describe "with correct credentials" do
        before do
          expect(app).to receive(:call).with(rack_env)
        end

        it "finds the right user with the correct credentials" do
          allow(rack_auth).to receive_messages(provided?: true, basic?: true, credentials: [ user1.name, pwd1 ])
          auther.call(rack_env)
          expect(store.current_user.uuid).to eq(user1.uuid)
        end

        it "finds the right user even when two users have same password" do
          allow(rack_auth).to receive_messages(provided?: true, basic?: true, credentials: [ user1.name, pwd1 ])
          user2.update(password: pwd1)
          auther.call(rack_env)
          expect(store.current_user.uuid).to eq(user1.uuid)
        end
      end
    end
  end
end
