require 'spec_helper'

module Transferatu
  describe RunnerFactory do
    describe "#make_runner" do
      [ [ 'postgres:///test1', 'postgres:///test2', false ],
        [ 'postgres:///test1', 'https://bucket.s3.amazonaws.com/some/key', true ],
        [ 'https://bucket.s3.amazonaws.com/some/key', 'postgres:///test1', false ],
        [ 'https://bucket.s3.amazonaws.com/some/key', 'https://bucket.s3.amazonaws.com/some/key', false ] ].each do |from, to, valid|
        context do
          let(:from_conn)   { double(:connection) }
          let(:from_result) { double(:result) }
          let(:transfer)    { double(:transfer, from_url: from, to_url: to) }
          before do
            def transfer.log
              # the RunnerFactory requires a #log method on its transfer
            end
          end
          # TODO: verify not just that several versions work, but that
          # the resulting runner has the expected version
          [
            "PostgreSQL 9.2.8 on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 4.8.2-16ubuntu6) 4.8.2, 64-bit",
            "PostgreSQL 9.3.4 on x86_64-unknown-linux-gnu, compiled by gcc (Ubuntu 4.8.2-16ubuntu6) 4.8.2, 64-bit"
          ].each do |version|
            it "#{if valid; "succeeds"; "fails"; end} with transfer from #{from} (version #{version}) to #{to}" do
              Sequel.should_receive(:connect).with(from).and_yield(from_conn)
              from_conn.should_receive(:fetch).with("SELECT version()").and_return(from_result)
              from_result.should_receive(:get).with(:version).and_return(version)
              if valid
                runner = RunnerFactory.make_runner(transfer)
                %i(run_transfer cancel processed_bytes).each do |action|
                  expect(runner).to respond_to(action)
                end
              else
                expect { RunnerFactory.make_runner(transfer) }.to raise_error ArgumentError
              end
            end
          end
        end
      end
    end
  end

  describe ShellProcessLike do
    let(:s) { Object.new.extend(ShellProcessLike) }
    describe '#command' do
      [
        [ 'git' , {}, [], %w(git) ],
        [ %w(git status) , {}, [], %w(git status) ],
        [ %w(git push) , {}, %w(origin master), %w(git push origin master) ],
        [ %w(git push) , {force: true}, %w(origin master), %w(git push --force origin master) ],
        [ %w(git push) , {f: true}, %w(origin master), %w(git push -f origin master) ],
        [ %w(git push) , {dry_run: true}, %w(origin master), %w(git push --dry-run origin master) ],
        [ %w(git push) , {n: true}, %w(origin master), %w(git push -n origin master) ],
        [ %w(git log) , {grep: "foo", n: 5, first_parent: true}, %w(master),
          %w(git log --grep foo -n 5 --first-parent master) ]
      ].each do |(cmd, opts, args, command)|
        it "should transform (#{cmd},#{opts},#{args}) to #{command}" do
          expect(s.command(cmd, opts, *args)).to eq(command)
        end
      end
    end

    describe "logging" do
      let(:results) { [] }
      before do
        s.stub(:logger).and_return(->(line, severity: :info) { results << line })
      end

      describe '#log' do
        it "logs individual lines" do
          s.log "hello"
          s.log "goodbye"
          expect(results).to eq(%w(hello goodbye))
        end
      end

      describe "#drain_log_lines" do
        it "drains a normal source" do
          source = StringIO.new("hello\ngoodbye")
          s.drain_log_lines(source)
          expect(results).to eq(%w(hello goodbye))
          expect(source).to be_closed
        end

        it "drains a one-line source" do
          source = StringIO.new("hello")
          s.drain_log_lines(source)
          expect(results).to eq(%w(hello))
          expect(source).to be_closed
        end

        it "drains an empty source" do
          source = StringIO.new("")
          s.drain_log_lines(source)
          expect(results).to be_empty
          expect(source).to be_closed
        end
      end
    end
  end

  describe PGDumpSource do
    let(:logs)     { [] }
    let(:logger)   { ->(line, severity: info) { logs << line } }
    let(:source)   { PGDumpSource.new("postgres:///test",
                                      logger: logger,
                                      env: { "PATH" => '/app/bin/pg/9.2/bin',
                                             "LD_LIBRARY_PATH" => '/app/bin/pg/9.2/lib'}) }
    let(:stdin)    { StringIO.new("") }
    let(:stdout)   { StringIO.new("") }
    let(:stderr)   { StringIO.new("hello\nfrom\npg_dump") }
    let(:wthr)     { double(:wthr, pid: 22) }
    let(:success)  { double(:process_status, exitstatus: 0, termsig: nil, success?: true) }
    let(:failure)  { double(:process_status, exitstatus: 1, termsig: nil, success?: false) }
    let(:signaled) { double(:process_status, exitstatus: nil, termsig: 14, success?: nil) }

    describe "#run_async" do
      before do
        Open3.should_receive(:popen3).with { |env, command| command =~ /pg_dump/ }
          .and_return([stdin, stdout, stderr, wthr])
      end

      it "closes stdin and returns stdout" do
        stream = source.run_async
        expect(stream).to be(stdout)
        expect(stdout).to_not be_closed
        expect(stdin).to be_closed
      end

      it "collects logs while running" do
        source.run_async
        wthr.should_receive(:value).and_return(success)
        source.wait
        %w(hello from pg_dump).each do |line|
          expect(logs).to include(line)
        end
      end

      # It's dicey to nest contexts, but #wait and #cancel are only
      # meaningful after a run_async
      describe "#wait" do
        it "returns success if the transfer finishes" do
          wthr.should_receive(:value).and_return(success)
          source.run_async
          result = source.wait
          expect(result).to be_true
        end

        it "returns failure if the transfer with an error" do
          wthr.should_receive(:value).and_return(failure)
          source.run_async
          result = source.wait
          expect(result).to be_false
        end

        it "returns failure if the transfer fails due to a signal" do
          wthr.should_receive(:value).and_return(signaled)
          source.run_async
          result = source.wait
          expect(result).to be_false
        end
      end

      describe "#cancel" do
        it "cancels the asynchronus process" do
          source.run_async
          Process.should_receive(:kill).with("INT", wthr.pid)
          source.cancel
        end

        it "ignores dead processes when canceling" do
          source.run_async
          Process.should_receive(:kill).with("INT", wthr.pid).and_raise(Errno::ESRCH)
          source.cancel
        end
      end
    end
  end

  describe Gof3rSink do
    let(:logs)     { [] }
    let(:logger)   { ->(line, severity: :info) { logs << line } }
    let(:sink)     { Gof3rSink.new("https://bucket.s3.amazonaws.com/some/key", logger: logger) }
    let(:stdin)    { StringIO.new("") }
    let(:stdout)   { StringIO.new("hello\nfrom\ngof3r") }
    let(:stderr)   { StringIO.new("and some stderr\nwhat the heck?") }
    let(:wthr)     { double(:wthr, pid: 22) }
    let(:success)  { double(:process_status, exitstatus: 0, termsig: nil, success?: true) }
    let(:failure)  { double(:process_status, exitstatus: 1, termsig: nil, success?: false) }
    let(:signaled) { double(:process_status, exitstatus: nil, termsig: 14, success?: nil) }

    describe "#run_async" do
      before do
        Open3.should_receive(:popen3).with { |*args| args.join('') =~ /gof3r/ }
          .and_return([stdin, stdout, stderr, wthr])
      end

      it "returns the target process' stdin" do
        stream = sink.run_async
        expect(stream).to be(stdin)
        expect(stream).to_not be_closed
      end

      it "collects logs while running" do
        sink.run_async
        wthr.should_receive(:value).and_return(success)
        sink.wait
        %w(hello from gof3r).each do |line|
          expect(logs).to include(line)
        end

        [ "and some stderr", "what the heck?" ].each do |line|
          expect(logs).to include(line)
        end
      end

      describe "#wait" do
        it "returns success if the transfer finishes" do
          wthr.should_receive(:value).and_return(success)
          sink.run_async
          result = sink.wait
          expect(result).to be_true
        end

        it "returns failure if the transfer with an error" do
          wthr.should_receive(:value).and_return(failure)
          sink.run_async
          result = sink.wait
          expect(result).to be_false
        end

        it "returns failure if the transfer fails due to a signal" do
          wthr.should_receive(:value).and_return(signaled)
          sink.run_async
          result = sink.wait
          expect(result).to be_false
        end
      end

      describe "#cancel" do
        it "cancels the asynchronus process" do
          sink.run_async
          Process.should_receive(:kill).with("INT", wthr.pid)
          sink.cancel
        end

        it "ignores dead processes when canceling" do
          sink.run_async
          Process.should_receive(:kill).with("INT", wthr.pid).and_raise(Errno::ESRCH)
          sink.cancel
        end
      end
    end
  end
end
