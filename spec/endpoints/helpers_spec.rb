require "spec_helper"

describe Transferatu::Endpoints::Serializer do
  class FakeSerializer; end
  class SerializerClient
    include Transferatu::Endpoints::Serializer

    serialize_with FakeSerializer

    def invoke_serializer(o)
      serialize(o)
    end

    def invoke_custom_serializer(o)
      serialize(o, flavor: :custom)
    end
  end
  let(:srlzr_class)    { FakeSerializer }
  let(:srlzr_instance) { double(:serializer) }
  let(:some_object)    { double(:some_object) }
  let(:client)         { SerializerClient.new }

  it "invokes the associated serializer" do
    srlzr_class.should_receive(:new).with(:default).and_return(srlzr_instance)
    srlzr_instance.should_receive(:serialize).with(some_object)
    client.invoke_serializer(some_object)
  end

  it "supports custom serialization flavors" do
    srlzr_class.should_receive(:new).with(:custom).and_return(srlzr_instance)
    srlzr_instance.should_receive(:serialize).with(some_object)
    client.invoke_custom_serializer(some_object)
  end
end
