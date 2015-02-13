module Transferatu

  # A DataMover transfers data between a data Source and a data Sink.
  # Both of these must support a simple API consisting of three
  # methods; both are very similar.
  #
  # For a Source:
  #
  # #perform_async - Asynchronously start producing data and return
  #                  an IO stream the data should be read from.
  # #wait          - Wait for the source of the data to drain and
  #                  be fully read by the consumer. The source
  #                  stream should return true from #eof? before
  #                  #wait returns. Should return true iff the
  #                  Source drained all its data to the source
  #                  stream.
  # #alive?        - Check if process is still running, by checking
  #                  if the monitor thread is still running.
  #                  Note: this thread is a just a c function which
  #                  calls wait(2).
  # #cancel        - Cancel producing data (but do not close the
  #                  source). Note that #wait will still be called
  #                  after #cancel, and should return as promptly
  #                  as possible. If #cancel is called, #wait must
  #                  return false.
  # For a Sink:
  #
  # #perform_async - Asynchronously start consuming data and return
  #                  an IO stream the data should be written to.
  #                  The stream will be closed by the DataMover to
  #                  indicate it's done writing data.
  # #wait          - Wait for the Sink to finish processing
  #                  data written to its input stream. Must be
  #                  called after the input stream is closed. Should
  #                  return true iff the Sink read and processed all
  #                  data from the stream.
  # #alive?        - Check if process is still running, by checking
  #                  if the monitor thread is still running.
  #                  Note: this thread is a just a c function which
  #                  calls wait(2).
  # #cancel        - Cancel consuming data (but do not close the
  #                  Sink). Note that #wait will still be called
  #                  after #cancel. If #cancel is called, #wait must
  #                  return false.
  #
  # Given these, a DataMover can transfer data from Source to Sink,
  # expose progress, and propagate cancelations.
  class DataMover

    CHUNK_SIZE = 512 * 1024

    def initialize(source, sink)
      @lock = Mutex.new
      @source = source
      @sink = sink
      @processed_bytes = 0
    end

    # Number of bytes read from the Source and written to the Sink
    def processed_bytes
      @lock.synchronize { @processed_bytes }
    end

    # Cancel a transfer
    def cancel
      @source.cancel
      @sink.cancel
    end

    # Run a transfer by moving data from Source to Sink. Return true
    # if the transfer completes successfully, and false if it fails or
    # if it is canceled.
    def run_transfer
      source_result = nil
      sink_result = nil
      begin
        source_stream = @source.run_async
        sink_stream = @sink.run_async

        begin
          until source_stream.eof? || !@source.alive? || !@sink.alive?
            copied = IO.copy_stream(source_stream, sink_stream, CHUNK_SIZE)
            @lock.synchronize { @processed_bytes += copied }
          end
        rescue Errno::EPIPE
          # Writing failed because the sink died: we trust the sink to
          # log the error in this case and return a failure from
          # #wait. Note that if the source fails, we'll exit this loop
          # normally (due to the source stream eof), but the source will
          # notice it failed and log and update transfer status
          # accordingly.
        ensure
          sink_stream.close
        end
      ensure
        source_result = @source.wait if source_stream
        sink_result = @sink.wait if sink_stream
      end
      source_result && sink_result
    end
  end
end
