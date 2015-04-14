require "spec_helper"

describe Transferatu::Mediators::Transfers::Evictor do
  let(:group)     { create(:group) }
  let(:num_keep)  { 3 }
  let(:dbname)    { 'db1' }
  let(:xfer)      { create(:transfer,
                           group: group,
                           from_name: dbname,
                           to_type: 'gof3r',
                           num_keep: num_keep) }

  before do
    5.times { create(:transfer,
                     group: xfer.group,
                     from_name: dbname,
                     to_type: 'gof3r',
                     succeeded: true) }
  end

  it "evicts live backups past threshold" do
    Transferatu::Mediators::Transfers::Evictor.run(transfer: xfer)
    # N.B.: because we haven't created any *other* transfers, we
    # simply look at all transfers for the group; this may need to be
    # refined if this test needs to get more complex.
    group.transfers_dataset
      .where(succeeded: true, from_name: dbname, to_type: 'gof3r')
      .present.order_by(Sequel.desc(:created_at)).all.each_with_index do |xfer, i|
      expect(xfer.deleted?).to be (i > num_keep)
    end
  end

  it "ignores transfers with non-gof3r target" do
    other_xfer = create(:transfer, group: group,
                        created_at: Time.now - 10.minutes, succeeded: true,
                        from_name: dbname, to_type: 'pg_restore')
    Transferatu::Mediators::Transfers::Evictor.run(transfer: xfer)
    expect(other_xfer.deleted?).to be false
  end

  it "does not count failed transfers against limit" do
    failed_xfer = create(:transfer, group: xfer.group,
                         from_name: dbname, to_type: 'gof3r',
                         succeeded: false)
    Transferatu::Mediators::Transfers::Evictor.run(transfer: xfer)
    group.transfers_dataset
      .where(succeeded: true, from_name: dbname, to_type: 'gof3r')
      .present.order_by(Sequel.desc(:created_at)).all.each_with_index do |xfer, i|
      expect(xfer.deleted?).to be (i > num_keep)
    end
    expect(failed_xfer.deleted?).to be false
  end

  it "does not count scheduled transfers against limit" do
    schedule = create(:schedule)
    scheduled_xfer = create(:transfer, group: xfer.group,
                            from_name: dbname, to_type: 'gof3r',
                            succeeded: true, schedule: schedule)
    Transferatu::Mediators::Transfers::Evictor.run(transfer: xfer)
    group.transfers_dataset
      .where(schedule_id: nil, from_name: dbname, to_type: 'gof3r')
      .present.order_by(Sequel.desc(:created_at)).all.each_with_index do |xfer, i|
      expect(xfer.deleted?).to be (i > num_keep)
    end
    expect(scheduled_xfer.deleted?).to be false
  end
end
