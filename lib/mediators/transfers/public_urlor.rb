module Transferatu
  module Mediators::Transfers
    class PublicUrlor < Mediators::Base
      def initialize(transfer:, ttl:)
        @transfer = transfer
        @ttl = ttl
      end

      def call
        unless @transfer.to_type == 'gof3r'
          raise ArgumentError, "Can only generate public URL for backup transfers"
        end
        unless @transfer.succeeded?
          raise ArgumentError, "Can only generate public URL for completed transfers"
        end
        s3_uri = URI.parse(@transfer.to_url)
        bucket_name = s3_uri.hostname.split('.').first
        object_id = s3_uri.path[1..-1]

        s3 = Aws::S3::Client.new(access_key_id: Config.aws_access_key_id,
                                 secret_access_key: Config.aws_secret_access_key,
                                 region: 'us-east-1')
        presigner = Aws::S3::Presigner.new(client: s3)
        presigner.presigned_url(:get_object,
                                bucket: bucket_name,
                                key: object_id,
                                expires_in: @ttl)
      end
    end
  end
end
