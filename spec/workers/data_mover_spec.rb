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

      expect(source).to receive(:alive?).and_return(true)
      expect(sink).to receive(:alive?).and_return(true)

      expect(source).to receive(:wait).and_return(true)
      expect(sink).to receive(:wait).and_return(true)

      expect(mover.run_transfer).to be true

      expect(mover.processed_bytes).to eq(short_source.length)
      expect(sink_stream.length).to eq(short_source.length)
    end

    it "should run transfers larger than chunk size" do
      expect(source).to receive(:run_async).and_return(long_source)
      expect(sink).to receive(:run_async).and_return(sink_stream)

      expect(source).to receive(:alive?).twice.and_return(true)
      expect(sink).to receive(:alive?).twice.and_return(true)

      expect(source).to receive(:wait).and_return(true)
      expect(sink).to receive(:wait).and_return(true)

      expect(mover.run_transfer).to be true

      expect(mover.processed_bytes).to eq(long_source.length)
      expect(sink_stream.length).to eq(long_source.length)
    end

    it "should stop the transfer if the source fails" do
      
    end

    it "should stop the transfer if the sink fails" do
      expect(source).to receive(:run_async).and_return(long_source)
      expect(sink).to receive(:run_async).and_return(sink_stream)

      expect(source).to receive(:alive?).and_return(true)
      expect(sink).to receive(:alive?).and_return(true)

      expect(sink_stream).to receive(:write).and_raise(Errno::EPIPE)

      expect(source).to receive(:wait).and_return(true)
      expect(sink).to receive(:wait).and_return(false)

      expect(mover.run_transfer).to be false
    end

    it "should stop the transfer and raise if copying data fails" do
      expect(source).to receive(:run_async).and_return(long_source)
      err = StandardError.new("oh snap")
      expect(sink).to receive(:run_async).and_return(sink_stream)
      expect(IO).to receive(:copy_stream).and_raise(err)

      expect(source).to receive(:alive?).and_return(true)
      expect(sink).to receive(:alive?).and_return(true)

      expect(source).to receive(:wait).and_return(true)
      expect(sink).to receive(:wait).and_return(true)

      expect { mover.run_transfer }.to raise_error(err)
    end

    it "should raise if source fails to run" do
      err = StandardError.new("oh snap")
      expect(source).to receive(:run_async).and_raise(err)

      expect(source).not_to receive(:wait)
      expect(sink).not_to receive(:wait)

      expect { mover.run_transfer }.to raise_error(err)
    end

    it "should clean up source and raise if sink fails to run" do
      expect(source).to receive(:run_async).and_return(long_source)
      err = StandardError.new("oh snap")
      expect(sink).to receive(:run_async).and_raise(err)

      expect(source).to receive(:wait).and_return(true)
      expect(sink).not_to receive(:wait)

      expect { mover.run_transfer }.to raise_error(err)
    end
    
    it "should cancel the source and sink when cancelled externally" do
      expect(source).to receive(:cancel)
      expect(sink).to receive(:cancel)

      mover.cancel
    end
  end
end
