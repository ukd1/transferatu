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
      source.should_receive(:run_async).and_return(short_source)
      sink.should_receive(:run_async).and_return(sink_stream)

      source.should_receive(:wait)
      sink.should_receive(:wait)

      mover.run_transfer

      expect(mover.processed_bytes).to eq(short_source.length)
      expect(sink_stream.length).to eq(short_source.length)
    end

    it "should run transfers larger than chunk size" do
      source.should_receive(:run_async).and_return(long_source)
      sink.should_receive(:run_async).and_return(sink_stream)

      source.should_receive(:wait)
      sink.should_receive(:wait)

      mover.run_transfer

      expect(mover.processed_bytes).to eq(long_source.length)
      expect(sink_stream.length).to eq(long_source.length)
    end

    it "should stop the transfer if the source fails" do
      
    end

    it "should stop the transfer if the sink fails" do
      source.should_receive(:run_async).and_return(long_source)
      sink.should_receive(:run_async).and_return(sink_stream)

      sink_stream.should_receive(:write).and_raise(Errno::EPIPE)

      source.should_receive(:wait)
      sink.should_receive(:wait)

      mover.run_transfer
    end

    it "should stop the transfer and raise if copying data fails" do
      source.should_receive(:run_async).and_return(long_source)
      err = StandardError.new("oh snap")
      sink.should_receive(:run_async).and_return(sink_stream)
      IO.should_receive(:copy_stream).and_raise(err)

      source.should_receive(:wait)
      sink.should_receive(:wait)

      expect { mover.run_transfer }.to raise_error(err)
    end

    it "should raise if source fails to run" do
      err = StandardError.new("oh snap")
      source.should_receive(:run_async).and_raise(err)

      source.should_not_receive(:wait)
      sink.should_not_receive(:wait)

      expect { mover.run_transfer }.to raise_error(err)
    end

    it "should clean up source and raise if sink fails to run" do
      source.should_receive(:run_async).and_return(long_source)
      err = StandardError.new("oh snap")
      sink.should_receive(:run_async).and_raise(err)

      source.should_receive(:wait)
      sink.should_not_receive(:wait)

      expect { mover.run_transfer }.to raise_error(err)
    end
    
    it "should cancel the source and sink when cancelled externally" do
      source.should_receive(:cancel)
      sink.should_receive(:cancel)

      mover.cancel
    end
  end
end
