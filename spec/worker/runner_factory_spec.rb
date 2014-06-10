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
        Open3.should_receive(:popen3).and_return([stdin, stdout, stderr, wthr])
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
      let(:success)  { double(:process_status, exitstatus: 0, termsig: nil, success?: true) }
      let(:failure)  { double(:process_status, exitstatus: 1, termsig: nil, success?: false) }
      let(:signaled) { double(:process_status, exitstatus: nil, termsig: 14, success?: nil) }

      let(:stdin)    { StringIO.new("hello") }
      let(:stdout)   { StringIO.new("hello") }
      let(:stderr)   { StringIO.new("hello") }
      let(:status)   { double(:process_status, success?: true) }
      let(:wthr)     { double(:wthr, value: status) }

      let(:future)   { ShellFuture.new(stdin, stdout, stderr, wthr) }

      it "returns true when successful" do
        wthr.stub(:value).and_return(success)
        expect(future.wait).to be_true
      end

      it "returns false when failed" do
        wthr.stub(:value).and_return(failure)
        expect(future.wait).to be_false
      end

      it "returns false when signaled" do
        wthr.stub(:value).and_return(signaled)
        expect(future.wait).to be_false
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
        Process.should_receive(:kill).with("INT", wthr.pid)
        future.cancel
      end

      it "ignores dead processes when canceling" do
        Process.should_receive(:kill).with("INT", wthr.pid).and_raise(Errno::ESRCH)
        future.cancel
      end
    end
  end

  describe PGDumpSource do
    let(:root)     { "/app/bin/pg/9.2" }
    let(:url)      { "postgres:///test" }
    let(:logger)   { ->(line, severity: :info) {} }
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
        source.should_receive(:run_command) do |env, command|
          expect(command).to include("#{root}/bin/pg_dump", url)
          expect(env["LD_LIBRARY_PATH"]).to eq("#{root}/lib")
        end.and_return(future)
      end

      it "returns stdout" do
        stream = source.run_async
        expect(stream).to be(stdout)
        expect(stdout).to_not be_closed
      end

      it "collects logs while running" do
        future.should_receive(:drain_stderr).with(logger)
        source.run_async
      end

      describe "#wait" do
        before do
          source.run_async
        end
        it "delegates to the ShellFuture#wait when the process succeeds" do
          future.should_receive(:wait).and_return(true)
          expect(source.wait).to be_true
        end
        it "delegates to the ShellFuture#wait when the process fails" do
          future.should_receive(:wait).and_return(false)
          expect(source.wait).to be_false
        end
      end

      describe "#cancel" do
        before do
          source.run_async
        end
        it "delegates to ShellProcess#cancel" do
          future.should_receive(:cancel)
          source.cancel
        end
      end
    end
  end

  describe Gof3rSink do
    let(:logger)   { ->(line, severity: :info) {} }
    let(:sink)     { Gof3rSink.new("https://my-bucket.s3.amazonaws.com/some/key", logger: logger) }
    let(:stdin)    { double(:stdin) }
    let(:stdout)   { double(:stdout) }
    let(:stderr)   { double(:stderr) }
    let(:wthr)     { double(:wthr, pid: 22) }
    let(:future)   { ShellFuture.new(stdin, stdout, stderr, wthr) }

    describe "#run_async" do
      before do
        sink.should_receive(:run_command) do |command|
          expect(command).to include('gof3r', 'my-bucket', 'some/key')
        end.and_return(future)
      end

      it "returns the target process' stdin" do
        stream = sink.run_async
        expect(stream).to be(stdin)
        expect(stream).to_not be_closed
      end

      it "collects logs while running" do
        future.should_receive(:drain_stdout).with(logger)
        future.should_receive(:drain_stderr) do |logfn|
          # TODO: we should also verify here that logger is being called
          expect(logfn).to respond_to(:call)
        end
        sink.run_async
      end

      describe "#wait" do
        before do
          sink.run_async
        end
        it "delegates to the ShellFuture#wait when the process succeeds" do
          future.should_receive(:wait).and_return(true)
          expect(sink.wait).to be_true
        end
        it "delegates to the ShellFuture#wait when the process fails" do
          future.should_receive(:wait).and_return(false)
          expect(sink.wait).to be_false
        end
      end

      describe "#cancel" do
        before do
          sink.run_async
        end
        it "delegates to ShellProcess#cancel" do
          future.should_receive(:cancel)
          sink.cancel
        end
      end
    end
  end

  describe PgRestoreSink do
    let(:root)     { "/app/bin/pg/9.2" }
    let(:url)      { "postgres:///test" }
    let(:logger)   { ->(line, severity: :info) {} }
    let(:stdin)    { double(:stdin) }
    let(:stdout)   { double(:stdout) }
    let(:stderr)   { double(:stderr) }
    let(:wthr)     { double(:wthr) }
    let(:sink)     { PgRestoreSink.new(url,
                                       logger: logger,
                                       root: root) }
    let(:future)   { ShellFuture.new(stdin, stdout, stderr, wthr) }

    describe "#run_async" do
      before do
        sink.should_receive(:run_command) do |env, command|
          expect(command).to include("#{root}/bin/pg_restore", url)
          expect(env["LD_LIBRARY_PATH"]).to eq("#{root}/lib")
        end.and_return(future)
      end

      it "returns the target process stdin" do
        stream = sink.run_async
        expect(stream).to be(stdin)
        expect(stream).to_not be_closed
      end

      it "collects logs while running" do
        future.should_receive(:drain_stderr).with(logger)
        sink.run_async
      end

      describe "#wait" do
        before do
          sink.run_async
        end
        it "delegates to the ShellFuture#wait when the process succeeds" do
          future.should_receive(:wait).and_return(true)
          expect(sink.wait).to be_true
        end
        it "delegates to the ShellFuture#wait when the process fails" do
          future.should_receive(:wait).and_return(false)
          expect(sink.wait).to be_false
        end
      end

      describe "#cancel" do
        before do
          sink.run_async
        end
        it "delegates to ShellProcess#cancel" do
          future.should_receive(:cancel)
          sink.cancel
        end
      end
    end
  end
end
