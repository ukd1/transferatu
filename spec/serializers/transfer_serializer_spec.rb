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
end
