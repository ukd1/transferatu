require "spec_helper"

describe Transferatu::Serializers::Transfer do
  let(:xfer) { create(:transfer) }
  let(:serializer) { Transferatu::Serializers::Transfer.new(:default) }

  it "serializes a transfer" do
    expect { serializer.serialize(xfer) }.to_not raise_error
  end

  it "does not include schedule information for a manual transfer" do
    result = serializer.serialize(xfer)
    expect(result[:schedule]).to be_nil
  end

  it "includes schedule info for a scheduled transfer" do
    xfer.schedule = create(:schedule)
    result = serializer.serialize(xfer)
    expect(result[:schedule]).to_not be_nil
  end

  context "verbose representation" do
    let(:serializer) { Transferatu::Serializers::Transfer.new(:verbose) }
    let(:message)    { 'hello world' }

    it "includes logs" do
      xfer.log(message)
      result = serializer.serialize(xfer)
      expect(result[:logs].count).to eq(1)
      log_item = result[:logs].first
      expect(log_item[:created_at]).not_to be_nil
      expect(log_item[:level]).to eq('info')
      expect(log_item[:message]).to eq(message)
    end

    it "excludes internal log lines" do
      xfer.log(message)
      xfer.log("some internal note", level: :internal)
      result = serializer.serialize(xfer)
      expect(result[:logs].count).to eq(1)
      expect(result[:logs].first[:message]).to eq(message)
    end

    it "includes all logs" do
      201.times { xfer.log(message) }
      result = serializer.serialize(xfer)
      expect(result[:logs].count).to eq(201)
    end
  end
end
