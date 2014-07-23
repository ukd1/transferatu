require "spec_helper"

module Transferatu
  describe Mediators::Groups::Creator do
    describe ".call" do
      let(:user)         { create(:user) }
      let(:another_user) { create(:user) }
      let(:name)         { 'default' }
      let(:log_url)      { 'https://token:t.8cda5772-ba01-49ec-9431-4391a067a0d3@example.com/logs' }

      it "creates a new group" do
        creator = Mediators::Groups::Creator.new(name: name, user: user)
        g = creator.call
        expect(g).to_not be_nil
        expect(g).to be_instance_of(Transferatu::Group)
        expect(g.name).to eq(name)
      end

      it "accepts an optional log_client_url" do
        creator = Mediators::Groups::Creator.new(name: name, user: user, log_input_url: log_url)
        g = creator.call
        expect(g).to_not be_nil
        expect(g).to be_instance_of(Transferatu::Group)
        expect(g.log_input_url).to eq(log_url)
      end

      it "forbids two groups with the same name for the same user" do
        c1 = Mediators::Groups::Creator.new(name: name, user: user)
        c1.call
        c2 = Mediators::Groups::Creator.new(name: name, user: user)
        expect { c2.call }.to raise_error
      end

      it "allows two groups with the same name for different users" do
        c1 = Mediators::Groups::Creator.new(name: name, user: user)
        g1 = c1.call
        c2 = Mediators::Groups::Creator.new(name: name, user: another_user)
        g2 = c2.call
        expect(g1.name).to eq(name)
        expect(g2.name).to eq(name)
      end
    end
  end
end
