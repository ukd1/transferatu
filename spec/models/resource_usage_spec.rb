require 'spec_helper'

describe Transferatu::ResourceUsage do
  describe ".tracking" do
    before do
      allow(Socket).to receive(:gethostname).and_return('0455ef1a-65ee-4dee-9a9f-d59ad8d14a95')
    end

    it "records the desired process metrics" do
      execution_id = 'b367f1c7-7f4b-4a1a-9726-bb606ae22737'
      Transferatu::ResourceUsage.tracking(execution_id, 'sleep', track_every: 0.1) do
        `sleep 1`
      end
      exec_info = Transferatu::ResourceUsage.all
      expect(exec_info.count).to be > 1
      expect(exec_info.all? { |info| info.foreign_uuid == execution_id }).to be true
      expect(exec_info.all? { |info| info.process_type == 'sleep' }).to be true
      expect(exec_info.all? { |info| info.rss_kb > 0 && info.rss_kb < 10000 }).to be true
      expect(exec_info.all? { |info| info.vsz_kb > 0 && info.vsz_kb < 20000 }).to be true
      expect(exec_info.all? { |info| info.pcpu >= 0 && info.pcpu <= 100 }).to be true
    end
  end
end
