require "spec_helper"

describe Transferatu::Group do
  describe "#log" do
    let(:group) { create(:group) }

    it "should use Lpxc to log to logplex" do
      message = "hello world"
      expect(Lpxc).to receive(:puts)
        .with(message, group.log_input_url, procid: Config.logplex_procid)
      group.log message
    end
  end
end
