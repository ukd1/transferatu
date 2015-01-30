require 'spec_helper'

module Transferatu
  describe RunnerFactory do
    describe "#runner_for" do
      [ [ 'pg_dump', 'postgres:///test1', 'pg_restore', 'postgres:///test2', true ],
        [ 'pg_dump', 'postgres:///test1', 'gof3r', 'https://bucket.s3.amazonaws.com/some/key', true ],
        [ 'gof3r', 'https://bucket.s3.amazonaws.com/some/key', 'pg_restore', 'postgres:///test1', true ],
        [ 'gof3r', 'https://bucket.s3.amazonaws.com/some/key', 'gof3r', 'https://bucket.s3.amazonaws.com/some/key', false ] ].each do |from_type, from, to_type, to, valid|
        context do
          let(:from_conn)        { double(:connection) }
          let(:from_size_result) { double(:size_result) }
          let(:from_size)        { 123234345 }
          let(:from_result)      { double(:result) }
          let(:to_conn)          { double(:connection) }
          let(:to_result)        { double(:result) }
          let(:transfer)         { double(:transfer,
                                     from_type: from_type, from_url: from,
                                     to_type: to_type, to_url: to) }
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
              if from_type == 'pg_dump'
                expect(Sequel).to receive(:connect).with(from).and_yield(from_conn).twice
                expect(from_conn).to receive(:fetch)
                  .with("SELECT pg_database_size(current_database()) AS size")
                  .and_return(from_size_result)
                expect(from_size_result).to receive(:get).with(:size).and_return(from_size)
                expect(from_conn).to receive(:fetch).with("SELECT version()").and_return(from_result)
                expect(from_result).to receive(:get).with(:version).and_return(version)

                expect(transfer).to receive(:update).with(source_bytes: from_size)
              end
              if to_type == 'pg_restore'
                expect(Sequel).to receive(:connect).with(to).and_yield(to_conn)
                expect(to_conn).to receive(:fetch).with("SELECT version()").and_return(to_result)
                expect(to_result).to receive(:get).with(:version).and_return(version)
              end

              if valid
                runner = RunnerFactory.runner_for(transfer)
                %i(run_transfer cancel processed_bytes).each do |action|
                  expect(runner).to respond_to(action)
                end
              else
                expect { RunnerFactory.runner_for(transfer) }.to raise_error ArgumentError
              end
            end
          end
        end
      end
    end
  end

  describe Commandable do
    let(:s) { Object.new.extend(Commandable) }
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
    describe "#run_command" do
      let(:stdin)  { double(:stdin) }
      let(:stdout) { double(:stdout) }
      let(:stderr) { double(:stderr) }
      let(:wthr)   { double(:wthr) }
      let(:env)    { double(:env) }
      let(:cmd)    { double(:cmd) }

      it "delegates to Open3.popen3 and wraps the result in a ShellFuture" do
        expect(::Open3).to receive(:popen3).and_return([stdin, stdout, stderr, wthr])
        result = s.run_command(env, cmd)
        expect(result).to be_instance_of(ShellFuture)
        expect(result.stdin).to be stdin
        expect(result.stdout).to be stdout
        expect(result.stderr).to be stderr
      end
    end
  end

  describe ShellFuture do
    let(:logs)   { [] }
    let(:logger) { ->(line) { logs << line } }

    describe "#drain_stdout" do
      let(:content) { %w(cello hang piano) }
      let(:stdin)   { StringIO.new("") }
      let(:stdout)  { StringIO.new(content.join("\n")) }
      let(:stderr)  { StringIO.new("") }
      let(:status)  { double(:process_status, success?: true) }
      let(:wthr)    { double(:wthr, value: status) }
      let(:future)  { ShellFuture.new(stdin, stdout, stderr, wthr) }

      it "drains stdout to a function" do
        future.drain_stdout(logger)
        future.wait
        expect(logs).to match_array(content)
      end
    end

    describe "#drain_stderr" do
      let(:content) { %w(kiwi orange pineapple) }
      let(:stdin)   { StringIO.new("") }
      let(:stdout)  { StringIO.new("") }
      let(:stderr)  { StringIO.new(content.join("\n")) }
      let(:status)  { double(:process_status, success?: true) }
      let(:wthr)    { double(:wthr, value: status) }
      let(:future)  { ShellFuture.new(stdin, stdout, stderr, wthr) }

      it "drains stderr to a function" do
        future.drain_stderr(logger)
        future.wait
        expect(logs).to match_array(content)
      end
    end

    describe "#wait" do
      let(:status)   { double(:process_status) }
      let(:stdin)    { StringIO.new("hello") }
      let(:stdout)   { StringIO.new("hello") }
      let(:stderr)   { StringIO.new("hello") }
      let(:status)   { double(:process_status, success?: true) }
      let(:wthr)     { double(:wthr, value: status) }

      let(:future)   { ShellFuture.new(stdin, stdout, stderr, wthr) }

      it "returns the process status" do
        allow(wthr).to receive(:value).and_return(status)
        expect(future.wait).to be status
      end

      it "closes all open streams" do
        future.wait
        expect(stdin).to be_closed
        expect(stdout).to be_closed
        expect(stderr).to be_closed
      end

      it "closes remaining streams if one is already closed" do
        stdin.close
        future.wait
        expect(stdin).to be_closed
        expect(stdout).to be_closed
        expect(stderr).to be_closed
      end
    end

    describe "#cancel" do
      let(:stdin)    { double(:stdin) }
      let(:stdout)   { double(:stdout) }
      let(:stderr)   { double(:stderr) }
      let(:wthr)     { double(:wthr, pid: 42) }
      let(:future)   { ShellFuture.new(stdin, stdout, stderr, wthr) }

      it "cancels the asynchronus process" do
        expect(Process).to receive(:kill).with("INT", wthr.pid)
        future.cancel
      end

      it "ignores dead processes when canceling" do
        expect(Process).to receive(:kill).with("INT", wthr.pid).and_raise(Errno::ESRCH)
        future.cancel
      end
    end
  end

  describe PGDumpSource do
    let(:success)  { double(:process_status, exitstatus: 0, termsig: nil, success?: true) }
    let(:failure)  { double(:process_status, exitstatus: 1, termsig: nil, success?: false) }
    let(:signaled) { double(:process_status, exitstatus: nil, termsig: 14, success?: nil) }

    let(:root)     { "/app/bin/pg/9.2" }
    let(:url)      { "postgres:///test" }
    let(:logger)   { ->(line, level: :info) {} }
    let(:stdin)    { double(:stdin) }
    let(:stdout)   { double(:stdout) }
    let(:stderr)   { double(:stderr) }
    let(:wthr)     { double(:wthr) }
    let(:source)   { PGDumpSource.new(url,
                                      logger: logger,
                                      root: root) }
    let(:future)   { ShellFuture.new(stdin, stdout, stderr, wthr) }

    describe "#run_async" do
      before do
        expect(source).to receive(:run_command) { |env, command|
          expect(command).to include("#{root}/bin/pg_dump", url)
          expect(env["LD_LIBRARY_PATH"]).to eq("#{root}/lib")
        }.and_return(future)
      end

      it "returns stdout" do
        stream = source.run_async
        expect(stream).to be(stdout)
        expect(stdout).to_not be_closed
      end

      it "collects logs while running" do
        expect(future).to receive(:drain_stderr).with(logger)
        source.run_async
      end

      describe "#wait" do
        before do
          source.run_async
        end
        it "returns true when the process succeeds" do
          expect(future).to receive(:wait).and_return(success)
          expect(source.wait).to be true
        end
        it "returns false when the process fails" do
          expect(future).to receive(:wait).and_return(failure)
          expect(source.wait).to be false
        end
        it "returns false when the process is signaled" do
          expect(future).to receive(:wait).and_return(signaled)
          expect(source.wait).to be false
        end
      end

      describe "#cancel" do
        before do
          source.run_async
        end
        it "delegates to ShellProcess#cancel" do
          expect(future).to receive(:cancel)
          source.cancel
        end
      end
    end
  end

  describe Gof3rSink do
    let(:success)  { double(:process_status, exitstatus: 0, termsig: nil, success?: true) }
    let(:failure)  { double(:process_status, exitstatus: 1, termsig: nil, success?: false) }
    let(:signaled) { double(:process_status, exitstatus: nil, termsig: 14, success?: nil) }

    let(:transfer) { create(:transfer) }
    let(:logger)   { ThreadSafeLogger.new(transfer).method(:log) }
    let(:sink)     { Gof3rSink.new("https://my-bucket.s3.amazonaws.com/some/key", logger: logger) }
    let(:stdin)    { StringIO.new }
    let(:stdout)   { StringIO.new("some\nstandard\nout") }
    let(:stderr)   { StringIO.new("1\n2\n3\n") }
    let(:wthr)     { double(:wthr, pid: 22) }
    let(:future)   { ShellFuture.new(stdin, stdout, stderr, wthr) }

    describe "#run_async" do
      before do
        expect(sink).to receive(:run_command) { |command|
          expect(command).to include('gof3r', 'my-bucket', 'some/key')
        }.and_return(future)
      end

      it "returns the target process' stdin" do
        stream = sink.run_async
        expect(stream).to be(stdin)
        expect(stream).to_not be_closed
      end

      it "collects logs while running" do
        sink.run_async
        allow(wthr).to receive(:value).and_return(success)
        sink.wait
        expect(transfer.logs(limit: -1).map(&:message)).to include(*%w(1 2 3))
      end

      describe "#wait" do
        before do
          sink.run_async
        end
        it "returns true when the process succeeds" do
          expect(future).to receive(:wait).and_return(success)
          expect(sink.wait).to be true
        end
        it "returns false when the process fails" do
          expect(future).to receive(:wait).and_return(failure)
          expect(sink.wait).to be false
        end
        it "returns false when the process is signaled" do
          expect(future).to receive(:wait).and_return(signaled)
          expect(sink.wait).to be false
        end
      end

      describe "#cancel" do
        before do
          sink.run_async
        end
        it "delegates to ShellProcess#cancel" do
          expect(future).to receive(:cancel)
          sink.cancel
        end
      end
    end
  end

  describe Gof3rSource do
    let(:success)  { double(:process_status, exitstatus: 0, termsig: nil, success?: true) }
    let(:failure)  { double(:process_status, exitstatus: 1, termsig: nil, success?: false) }
    let(:signaled) { double(:process_status, exitstatus: nil, termsig: 14, success?: nil) }

    let(:logger)   { ->(line, level: :info) {} }
    let(:source)   { Gof3rSource.new("https://my-bucket.s3.amazonaws.com/some/key", logger: logger) }
    let(:stdin)    { double(:stdin) }
    let(:stdout)   { double(:stdout) }
    let(:stderr)   { double(:stderr) }
    let(:wthr)     { double(:wthr, pid: 22) }
    let(:future)   { ShellFuture.new(stdin, stdout, stderr, wthr) }

    describe "#run_async" do
      before do
        expect(source).to receive(:run_command) { |command|
          expect(command).to include('gof3r', 'my-bucket', 'some/key')
        }.and_return(future)
      end

      it "returns the target process' stdin" do
        stream = source.run_async
        expect(stream).to be(stdout)
        expect(stream).to_not be_closed
      end

      it "collects logs while running" do
        expect(future).to receive(:drain_stderr).with(logger)
        source.run_async
      end

      describe "#wait" do
        before do
          source.run_async
        end
        it "returns true when the process succeeds" do
          expect(future).to receive(:wait).and_return(success)
          expect(source.wait).to be true
        end
        it "returns false when the process fails" do
          expect(future).to receive(:wait).and_return(failure)
          expect(source.wait).to be false
        end
        it "returns false when the process is signaled" do
          expect(future).to receive(:wait).and_return(signaled)
          expect(source.wait).to be false
        end
      end

      describe "#cancel" do
        before do
          source.run_async
        end
        it "delegates to ShellProcess#cancel" do
          expect(future).to receive(:cancel)
          source.cancel
        end
      end
    end
  end

  describe PGRestoreSink do
    let(:success)  { double(:process_status, exitstatus: 0, termsig: nil, success?: true) }
    let(:failure)  { double(:process_status, exitstatus: 1, termsig: nil, success?: false) }
    let(:signaled) { double(:process_status, exitstatus: nil, termsig: 14, success?: nil) }

    let(:root)     { "/app/bin/pg/9.2" }
    let(:url)      { "postgres:///test" }
    let(:logs)     { [] }
    let(:logger)   { ->(line, level: :info) { logs << line } }
    let(:stdin)    { double(:stdin) }
    let(:stdout)   { double(:stdout) }
    let(:stderr)   { double(:stderr) }
    let(:wthr)     { double(:wthr) }
    let(:sink)     { PGRestoreSink.new(url,
                                       logger: logger,
                                       root: root) }
    let(:future)   { ShellFuture.new(stdin, stdout, stderr, wthr) }

    describe "#run_async" do
      before do
        expect(sink).to receive(:run_command) { |env, command|
          expect(command).to include("#{root}/bin/pg_restore", url)
          expect(env["LD_LIBRARY_PATH"]).to eq("#{root}/lib")
        }.and_return(future)
      end

      it "returns the target process stdin" do
        stream = sink.run_async
        expect(stream).to be(stdin)
        expect(stream).to_not be_closed
      end

      it "collects logs while running" do
        expect(future).to receive(:drain_stderr) do |l|
          l.call("hello")
        end
        sink.run_async
        expect(logs).to include('hello')
      end

      describe "#wait" do
        it "returns true when the process succeeds" do
          expect(future).to receive(:wait).and_return(success)
          sink.run_async
          expect(sink.wait).to be true
        end
        it "returns true when the process fails with comment errors matching warning count" do
          expect(future).to receive(:wait).and_return(failure)
          expect(future).to receive(:drain_stderr) do |l|
            l.call "Command was: COMMENT ON EXTENSION plpgsql IS 'it is okay i guess'"
            l.call "Command was: COMMENT ON EXTENSION pg_stat_statements IS 'a damn fine extension'"
            l.call "WARNING: errors ignored on restore: 2"
          end
          sink.run_async
          expect(sink.wait).to be true
        end
        it "returns false when process fails with comment errors not matching warning count" do
          expect(future).to receive(:wait).and_return(failure)
          expect(future).to receive(:drain_stderr) do |l|
            l.call "Command was: COMMENT ON EXTENSION plpgsql IS 'hello'"
            l.call "WARNING: errors ignored on restore: 3"
          end
          sink.run_async
          expect(sink.wait).to be false
        end
        it "returns true when process fails with PL/pgSQL failure matching warning count" do
          expect(future).to receive(:wait).and_return(failure)
          expect(future).to receive(:drain_stderr) do |l|
            l.call "Command was: CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;"
            l.call "WARNING: errors ignored on restore: 1"
          end
          sink.run_async
          expect(sink.wait).to be true
        end
        it "returns false when process fails with PL/pgSQL failure not matching warning count" do
          expect(future).to receive(:wait).and_return(failure)
          expect(future).to receive(:drain_stderr) do |l|
            l.call "Command was: CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;"
            l.call "WARNING: errors ignored on restore: 2"
          end
          sink.run_async
          expect(sink.wait).to be false
        end
        it "returns true when the process fails with comment plus PL/pgSQL errors matching warning count" do
          expect(future).to receive(:wait).and_return(failure)
          expect(future).to receive(:drain_stderr) do |l|
            l.call "Command was: COMMENT ON EXTENSION pg_stat_statements IS 'a damn fine extension'"
            l.call "Command was: CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;"
            l.call "WARNING: errors ignored on restore: 2"
          end
          sink.run_async
          expect(sink.wait).to be true
        end
        it "returns false when the process fails otherwise" do
          expect(future).to receive(:wait).and_return(failure)
          sink.run_async
          expect(sink.wait).to be true
        end
        it "returns false when the process is signaled" do
          expect(future).to receive(:wait).and_return(signaled)
          sink.run_async
          expect(sink.wait).to be false
        end
        it "returns false when process is signaled and has comment errors matching warning count" do
          expect(future).to receive(:wait).and_return(signaled)
          expect(future).to receive(:drain_stderr) do |l|
            l.call "Command was: COMMENT ON EXTENSION plpgsql IS 'it is okay i guess'"
            l.call "Command was: COMMENT ON EXTENSION pg_stat_statements IS 'a damn fine extension'"
            l.call "WARNING: errors ignored on restore: 2"
          end
          sink.run_async
          expect(sink.wait).to be false
        end
      end

      describe "#cancel" do
        before do
          sink.run_async
        end
        it "delegates to ShellProcess#cancel" do
          expect(future).to receive(:cancel)
          sink.cancel
        end
      end
    end
  end
end
