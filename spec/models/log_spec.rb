require "spec_helper"

describe Transferatu::Log do
  let(:loggable) { class DummyLoggable
                     include Transferatu::Loggable
                     def uuid; "b367f1c7-7f4b-4a1a-9726-bb606ae22737"; end
                   end; DummyLoggable.new }
  let(:messages) {
    [ "Stardate 43125.8. We have entered a spectacular binary star system in",
      "the Kavis Alpha sector on a most critical mission of astrophysical research.",
      "Our eminent guest, Dr. Paul Stubbs, will attempt to study the decay of neutronium",
      "expelled at relativistic speeds from a massive stellar explosion which",
      "will occur here in a matter of hours" ]
  }

  describe "#log" do
    it "creates a log message" do
      message = messages.first
      Transferatu::Log.should_receive(:create)
        .with(message: message,
              level: "warning",
              foreign_uuid: loggable.uuid)
      loggable.log(message, level: :warning)
    end
    it "defaults to INFO level" do
      message = messages.first
      Transferatu::Log.should_receive(:create)
        .with(message: message,
              level: "info",
              foreign_uuid: loggable.uuid)
      loggable.log(message)
    end
  end

  describe "#logs" do
    let(:logged) { [] }
    before do
      messages.each do |msg|
        logged << Transferatu::Log.create(message: msg, level: "info",
                                          foreign_uuid: loggable.uuid)
      end
    end
    it "returns the most recent logs for the Loggable" do
      expect(loggable.logs.count).to eq(logged.length)
      # N.B.: these are not entirely equal as we don't pull in the foreign_uuid
      loggable.logs.zip(logged.reverse).each do |logged, expected|
        expect(logged.created_at).to eq(expected.created_at)
        expect(logged.level).to eq(expected.level)
        expect(logged.message).to eq(expected.message)
      end
    end
  end
end
