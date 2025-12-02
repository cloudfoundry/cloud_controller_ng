module Fog
  module Google
    module Parsers
      module Storage
        autoload :AccessControlList, 'fog/google/parsers/storage/access_control_list'
        autoload :CopyObject, 'fog/google/parsers/storage/copy_object'
        autoload :GetBucket, 'fog/google/parsers/storage/get_bucket'
        autoload :GetBucketLogging, 'fog/google/parsers/storage/get_bucket_logging'
        autoload :GetBucketObjectVersions, 'fog/google/parsers/storage/get_bucket_object_versions'
        autoload :GetRequestPayment, 'fog/google/parsers/storage/get_request_payment'
        autoload :GetService, 'fog/google/parsers/storage/get_service'
      end
    end
  end
end
