require 'spec_helper'

module Transferatu
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

    describe '#log' do
      let(:results) { [] }
      before do
        s.stub(:logger).and_return(->(line) { results << line })
      end
      it "logs individual lines" do
        s.log "hello"
        s.log "goodbye"
        expect(results).to eq(%w(hello goodbye))
      end
    end

    describe "#drain_log_lines" do
      let(:results) { [] }
      before do
        s.stub(:logger).and_return(->(line) { results << line })
      end

      it "drains a normal source" do
        source = StringIO.new("hello\ngoodbye")
        s.drain_log_lines(source)
        expect(results).to eq(%w(hello goodbye))
      end

      it "drains a one-line source" do
        source = StringIO.new("hello")
        s.drain_log_lines(source)
        expect(results).to eq(%w(hello))
      end

      it "drains an empty source" do
        source = StringIO.new("")
        s.drain_log_lines(source)
        expect(results).to be_empty
      end
    end
  end
end
