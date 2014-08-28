require "spec_helper"

module Transferatu
  describe Mediators::Transfers::Creator do
    describe ".call" do
      let(:group)     { create(:group, name: 'foo') }
      let(:schedule)  { create(:schedule, name: 'bar', group: group) }
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

      it "sets optional transfer from_name and to_name" do
        from_name = "my favorite database"
        to_name = "some backup"
        creator = Mediators::Transfers::Creator.new(group: group,
                                                    from_type: from_type,
                                                    from_url: from_url,
                                                    from_name: from_name,
                                                    to_type: to_type,
                                                    to_url: to_url,
                                                    to_name: to_name,
                                                    options: opts)
        t = creator.call
        expect(t).to_not be_nil
        expect(t).to be_instance_of(Transferatu::Transfer)
        expect(t.from_name).to eq(from_name)
        expect(t.to_name).to eq(to_name)
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

      it "accepts an optional schedule to tie the transfer to" do
        creator = Mediators::Transfers::Creator.new(schedule: schedule,
                                                    group: group,
                                                    from_type: 'pg_dump',
                                                    from_url: from_url,
                                                    to_type: 'gof3r',
                                                    to_url: 'auto',
                                                    options: opts)
        t = creator.call
        expect(t).to be_instance_of(Transferatu::Transfer)
        expect(t.schedule).to eq(schedule)
      end

      it "rejects a new transfer with a mimsatched schedule group" do
        schedule_for_other_group = create(:schedule)
        creator = Mediators::Transfers::Creator.new(schedule: schedule_for_other_group,
                                                    group: group,
                                                    from_type: 'pg_dump',
                                                    from_url: from_url,
                                                    to_type: 'gof3r',
                                                    to_url: 'auto',
                                                    options: opts)
        expect { creator.call }.to raise_error(Mediators::Transfers::InvalidTransferError)
      end
    end
  end
end
