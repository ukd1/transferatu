require "spec_helper"

describe Transferatu::Group do
  describe "#log" do
    let(:group) { create(:group) }

    context "with non-nil log_input_url" do
      it "should use Lpxc to log to logplex" do
        message = "hello world"
        expect(Lpxc).to receive(:puts)
          .with(message, group.log_input_url, procid: Config.logplex_procid)
        group.log message
      end
    end

    context "with nil log_input_url" do
      before do
        group.update(log_input_url: nil)
      end
      it "should do nothing" do
        message = "hello world"
        expect(Lpxc).to_not receive(:puts)
        group.log message
      end
    end
  end
end
