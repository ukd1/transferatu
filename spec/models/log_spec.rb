require "spec_helper"

describe Transferatu::Log do
  let(:loggable) { Class.new do
                     include Transferatu::Loggable
                     def uuid; "b367f1c7-7f4b-4a1a-9726-bb606ae22737"; end
                   end.new }
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
      expect(Transferatu::Log).to receive(:create)
        .with(message: message,
              level: "warning",
              foreign_uuid: loggable.uuid)
      loggable.log(message, level: :warning)
    end
    it "defaults to INFO level" do
      message = messages.first
      expect(Transferatu::Log).to receive(:create)
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

    describe "limits" do
      before do
        202.times do |n|
          Transferatu::Log.create(message: "message #{n}",
                                  level: "info",
                                  foreign_uuid: loggable.uuid)
        end
      end

      it "returns up to 200 logs by default" do
        expect(loggable.logs.count).to eq(200)
      end

      it "returns less logs with an explicit limit" do
        expect(loggable.logs(limit: 10).count).to eq(10)
      end

      it "returns more logs with an explicit limit" do
        expect(loggable.logs(limit: 201).count).to eq(201)
      end

      it "returns all logs with negative limit" do
        expect(loggable.logs(limit: -1).count)
          .to eq(Transferatu::Log.where(foreign_uuid: loggable.uuid).count)
      end
    end
  end
end

describe Transferatu::ThreadSafeLogger do
  let!(:lines)   { [] }
  let(:loggable) { Class.new do
                     include Transferatu::Loggable
                     def initialize(lines); @lines = lines; end
                     def uuid; "b376f1c7-74fb-aa41-9276-bb660ae22773"; end
                     def log(line, opts)
                       @lines << line
                       super
                     end
                   end.new(lines) }
  let(:logger)   { Transferatu::ThreadSafeLogger.new(loggable) }

  it "is safe for concurrent access from multiple threads" do
    # this is really only a smoke test
    10.times.map do |i|
      Thread.new do
        logger.log(i)
      end
    end.each(&:join)
    expect(lines.sort).to eq(10.times.to_a)
  end
end
