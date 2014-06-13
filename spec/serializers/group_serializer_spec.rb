require "spec_helper"

describe Transferatu::Serializers::Group do
  let(:group) { create(:group) }
  let(:serializer) { Transferatu::Serializers::Group.new(:default) }

  it "serializes a group" do
    expect { serializer.serialize(group) }.to_not raise_error
  end
end
