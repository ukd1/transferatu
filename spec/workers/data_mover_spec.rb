require 'spec_helper'

module Transferatu
  describe DataMover do
    let(:source)        { double(:source) }
    let(:short_source)  { StringIO.new('*' * (DataMover::CHUNK_SIZE / 2)) }
    let(:long_source)   { StringIO.new('*' * (DataMover::CHUNK_SIZE * 2)) }
    let(:sink)          { double(:sink) }
    let(:sink_stream)   { StringIO.new }
    let(:mover)         { DataMover.new(source, sink) }

    it "should run transfers smaller than chunk size" do
      expect(source).to receive(:run_async).and_return(short_source)
      expect(sink).to receive(:run_async).and_return(sink_stream)

      allow(sink).to receive(:alive?).and_return(true, false)
      allow(source).to receive(:alive?).and_return(false)

      allow(source).to receive(:wait).and_return(true)
      allow(sink).to receive(:wait).and_return(true)

      expect(mover.run_transfer).to be true

      expect(mover.processed_bytes).to eq(short_source.length)
      expect(sink_stream.length).to eq(short_source.length)
    end

    it "should run transfers larger than chunk size" do
      expect(source).to receive(:run_async).and_return(long_source)
      expect(sink).to receive(:run_async).and_return(sink_stream)

      allow(sink).to receive(:alive?).and_return(true, true, false)
      allow(source).to receive(:alive?).and_return(false)

      allow(source).to receive(:wait).and_return(true)
      allow(sink).to receive(:wait).and_return(true)

      expect(mover.run_transfer).to be true

      expect(mover.processed_bytes).to eq(long_source.length)
      expect(sink_stream.length).to eq(long_source.length)
    end

    it "should stop the transfer if reading from source raises" do
      expect(source).to receive(:run_async).and_return(long_source)
      expect(sink).to receive(:run_async).and_return(sink_stream)

      allow(source).to receive(:alive?).and_return(true)
      allow(sink).to receive(:alive?).and_return(true)

      err = StandardError.new("oh snap")
      expect(long_source).to receive(:read).and_raise(err)
      expect(source).to receive(:cancel)
      expect(sink).to receive(:cancel)
      expect(Rollbar).to receive(:error).with(err)

      expect(source).to receive(:wait).and_return(false)
      expect(sink).to receive(:wait).and_return(false)

      expect(mover.run_transfer).to be false
    end

    it "should stop the transfer if the sink fails" do
      expect(source).to receive(:run_async).and_return(long_source)
      expect(sink).to receive(:run_async).and_return(sink_stream)

      allow(source).to receive(:alive?).and_return(true)
      allow(sink).to receive(:alive?).and_return(true)

      expect(source).to receive(:cancel).at_least(1).times
      expect(sink).to receive(:cancel).at_least(1).times

      expect(sink_stream).to receive(:write).and_raise(Errno::EPIPE)

      expect(source).to receive(:wait).and_return(true, false)
      expect(sink).to receive(:wait).and_return(false, false)

      expect(mover.run_transfer).to be false
    end

    it "should stop the transfer and report to Rollbar if copying data fails" do
      expect(source).to receive(:run_async).and_return(long_source)
      err = StandardError.new("oh snap")
      expect(sink).to receive(:run_async).and_return(sink_stream)
      expect(IO).to receive(:copy_stream).and_raise(err)
      expect(Rollbar).to receive(:error).with(err)

      allow(source).to receive(:alive?).and_return(true, true, false)
      allow(sink).to receive(:alive?).and_return(true, true, false)

      expect(source).to receive(:cancel)
      expect(sink).to receive(:cancel)

      expect(source).to receive(:wait).and_return(false)
      expect(sink).to receive(:wait).and_return(false)

      expect(mover.run_transfer).to be false
    end

    it "should report to Rollbar if source fails to run" do
      err = StandardError.new("oh snap")
      expect(source).to receive(:run_async).and_raise(err)
      expect(Rollbar).to receive(:error).with(err)

      allow(source).to receive(:alive?).and_return(false)
      allow(sink).to receive(:alive?).and_return(false)

      expect(source).to receive(:wait)
      expect(sink).to receive(:wait)

      expect(mover.run_transfer).to be false
    end

    it "should clean up source and report to Rollbar if sink fails to run" do
      expect(source).to receive(:run_async).and_return(long_source)
      err = StandardError.new("oh snap")
      expect(sink).to receive(:run_async).and_raise(err)
      expect(Rollbar).to receive(:error).with(err)

      allow(source).to receive(:alive?).and_return(true)
      allow(sink).to receive(:alive?).and_return(false)

      expect(source).to receive(:cancel)
      expect(source).to receive(:wait).and_return(false)
      expect(sink).to receive(:wait)

      expect(mover.run_transfer).to be false
    end

    it "should cancel the source and sink when cancelled externally" do
      expect(source).to receive(:cancel)
      expect(sink).to receive(:cancel)

      mover.cancel
    end
  end
end
