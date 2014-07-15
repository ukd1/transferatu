require "spec_helper"

module Transferatu
  describe Mediators::Transfers::Creator do
    describe ".call" do
      let(:group)     { create(:group, name: 'foo') }
      let(:from_type) { 'pg_dump' }
      let(:from_url)  { 'postgres:///test1' }
      let(:to_type)   { 'pg_restore' }
      let(:to_url)    { 'postgres:///test2' }
      let(:opts)      { {} }

      it "creates a new transfer" do
        creator = Mediators::Transfers::Creator.new(group: group,
                                                    from_type: from_type,
                                                    from_url: from_url,
                                                    to_type: to_type,
                                                    to_url: to_url,
                                                    options: opts)
        t = creator.call
        expect(t).to_not be_nil
        expect(t).to be_instance_of(Transferatu::Transfer)
      end

      it "creates a new backup with an auto-generated gof3r target url" do
        creator = Mediators::Transfers::Creator.new(group: group,
                                                    from_type: 'pg_dump',
                                                    from_url: from_url,
                                                    to_type: 'gof3r',
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
                                                    from_type: 'pg_dump',
                                                    from_url: from_url,
                                                    to_type: 'gof3r',
                                                    to_url: 'https://bucket.s3.amazonaws.com/key',
                                                    options: opts)
        expect { creator.call }.to raise_error(Mediators::Transfers::InvalidTransferError)
      end

      { 'an invalid url' => 'not really a url at all',
        'a non-postgres url' => 'mysql://u:p@example.com/foo' }.each do |description, url|
        it "rejects a new transfer with #{description} source for pg_dump" do
          creator = Mediators::Transfers::Creator.new(group: group,
                                                      from_type: 'pg_dump',
                                                      from_url: url,
                                                      to_type: to_type,
                                                      to_url: to_url,
                                                      options: opts)
          expect { creator.call }.to raise_error(Mediators::Transfers::InvalidTransferError)
        end

        it "rejects a new transfer with #{description} target for pg_restore" do
          creator = Mediators::Transfers::Creator.new(group: group,
                                                      from_type: from_type,
                                                      from_url: from_url,
                                                      to_type: 'pg_restore',
                                                      to_url: url,
                                                      options: opts)
          expect { creator.call }.to raise_error(Mediators::Transfers::InvalidTransferError)
        end
      end
    end
  end
end
