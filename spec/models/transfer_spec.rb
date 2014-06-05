require "spec_helper"

module Transferatu
  describe Transfer do
    before do
      # keep our napping brief
      runner.stub(:sleep) { sleep 0.01 }
    end
  end
end
