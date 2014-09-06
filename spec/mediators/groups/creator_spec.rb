require "spec_helper"

module Transferatu
  describe Mediators::Groups::Creator do
    describe ".call" do
      let(:user)         { create(:user) }
      let(:another_user) { create(:user) }
      let(:name)         { 'default' }
      let(:log_url)      { 'https://token:t.8cda5772-ba01-49ec-9431-4391a067a0d3@example.com/logs' }

      it "creates a new group" do
        creator = Mediators::Groups::Creator.new(name: name, user: user, log_input_url: log_url)
        g = creator.call
        expect(g).to_not be_nil
        expect(g).to be_instance_of(Transferatu::Group)
        expect(g.log_input_url).to eq(log_url)
      end

      it "forbids two groups with the same name for the same user" do
        c1 = Mediators::Groups::Creator.new(name: name, user: user, log_input_url: log_url)
        c1.call
        c2 = Mediators::Groups::Creator.new(name: name, user: user, log_input_url: log_url)
        expect { c2.call }.to raise_error
      end

      it "allows two groups with the same name for different users" do
        c1 = Mediators::Groups::Creator.new(name: name, user: user, log_input_url: log_url)
        g1 = c1.call
        c2 = Mediators::Groups::Creator.new(name: name, user: another_user, log_input_url: log_url)
        g2 = c2.call
        expect(g1.name).to eq(name)
        expect(g2.name).to eq(name)
      end

      it "undeletes a matching deleted group for the user if one exists" do
        old_g = create(:group, user: user, log_input_url: log_url)
        old_g.delete
        new_log_url = "https://token:passw0rd@example.com/logs"
        creator = Mediators::Groups::Creator.new(name: name, user: user, log_input_url: new_log_url)
        g = creator.call
        expect(g).to_not be_nil
        expect(g).to be_instance_of(Transferatu::Group)
        expect(g.name).to eq(name)
        expect(g.log_input_url).to eq(new_log_url)
      end

      it "does not undelete a group of the same name belonging to a different user" do
        other_group = create(:group, user: another_user, name: name)
        other_group.delete
        # okay, playing fast and loose, but these are the boundaries
        # we're interested in here--we're trying to simulate the case
        # where we're not filtering the deleted group lookup properly
        # and get the wrong answer, and the best way to do that is to
        # ensure that the conflicting group is not actually in the
        # system except under another user, and then fake the
        # conflict.
        expect(user).to receive(:add_group).and_raise(Sequel::UniqueConstraintViolation)
        creator = Mediators::Groups::Creator.new(name: name, user: user, log_input_url: log_url)
        # here we expect an error because no group will be found for
        # the UniqueConstraintViolation we just raised
        expect { creator.call }.to raise_error(NoMethodError)
      end
    end
  end
end
