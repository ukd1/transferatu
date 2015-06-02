require "spec_helper"

module Transferatu
  describe Mediators::Transfers::PublicUrlor do
    describe ".call" do
      let(:bucket)     { "my-bucket" }
      let(:object_id)  { "some/object/in/this/bucket" }
      let(:transfer)   { create(:transfer,
                                to_type: 'gof3r',
                                to_url: "https://#{bucket}.s3.amazonaws.com/#{object_id}") }
      let(:ttl)        { 60.minutes }
      let(:s3_client)  { double(:s3_client) }
      let(:presigner)  { double(:s3_presigner) }
      let(:signed_url) { "https://#{bucket}.s3.amazonaws.com/#{object_id}?signature=totally_valid" }

      let(:aws_key_id) { 'my-key-id' }
      let(:aws_secret) { 'my-key-secret' }

      before do
        allow(Config).to receive(:aws_access_key_id).and_return(aws_key_id)
        allow(Config).to receive(:aws_secret_access_key).and_return(aws_secret)
      end

      it "creates a new signed url" do
        urlor = Mediators::Transfers::PublicUrlor.new(transfer: transfer, ttl: ttl)
        expect(Aws::S3::Client).to receive(:new)
          .with(access_key_id: aws_key_id,
                secret_access_key: aws_secret,
                region: 'us-east-1')
          .and_return(s3_client)
        expect(Aws::S3::Presigner).to receive(:new)
          .with(client: s3_client)
          .and_return(presigner)
        expect(presigner).to receive(:presigned_url)
          .with(:get_object,
                bucket: bucket,
                key: object_id,
                expires_in: ttl)
          .and_return(signed_url)

        transfer.complete
        url = urlor.call
        expect(url).to eq(signed_url)
      end

      it "raises if the transfer was not via gof3r" do
        transfer.update(to_type: 'pg_restore', to_url: 'postgres:///test')
        transfer.complete
        urlor = Mediators::Transfers::PublicUrlor.new(transfer: transfer, ttl: ttl)
        expect { urlor.call }.to raise_error(ArgumentError)
      end

      it "raises if the transfer did not yet finish" do
        urlor = Mediators::Transfers::PublicUrlor.new(transfer: transfer, ttl: ttl)
        expect { urlor.call }.to raise_error(ArgumentError)
      end

      it "raises if the transfer failed" do
        transfer.fail
        urlor = Mediators::Transfers::PublicUrlor.new(transfer: transfer, ttl: ttl)
        expect { urlor.call }.to raise_error(ArgumentError)
      end
    end
  end
end
