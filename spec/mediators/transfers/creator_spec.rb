require "spec_helper"

module Transferatu
  describe Mediators::Transfers::Creator do
    describe ".call" do
      let(:group)    { create(:group, name: 'foo') }
      let(:from_url) { 'postgres:///test1' }
      let(:to_url)   { 'https://bucket.s3.amazonaws.com/key' }
      let(:opts)     { {} }

      it "creates a new transfer" do
        creator = Mediators::Transfers::Creator.new(group: group,
                                                    type: 'pg_dump:pg_restore',
                                                    from_url: from_url,
                                                    to_url: to_url,
                                                    options: opts)
        t = creator.call
        expect(t).to_not be_nil
        expect(t).to be_instance_of(Transferatu::Transfer)
      end

      it "creates a new backup with an auto-generated gof3r target url" do
        creator = Mediators::Transfers::Creator.new(group: group,
                                                    type: 'pg_dump:gof3r',
                                                    from_url: from_url,
                                                    to_url: 'auto',
                                                    options: opts)
        t = creator.call
        expect(t).to_not be_nil
        expect(t.to_url).to_not eq('auto')
        expect { URI.parse(t.to_url) }.to_not raise_error
        expect(t).to be_instance_of(Transferatu::Transfer)
      end

      it "rejects a new transfer with an explicit gof3r target url" do
        creator = Mediators::Transfers::Creator.new(group: group,
                                                    type: 'pg_dump:gof3r',
                                                    from_url: from_url,
                                                    to_url: to_url,
                                                    options: opts)
        expect { creator.call }.to raise_error(Mediators::Transfers::InvalidTransferError)
      end
    end
  end
end
