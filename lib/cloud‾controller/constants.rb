module VCAP::CloudController
  class Constants
    API_VERSION = File.read(File.expand_path('../../config/version_v2', File.dirname(__FILE__))).strip.freeze
    API_VERSION_V3 = File.read(File.expand_path('../../config/version', File.dirname(__FILE__))).strip.freeze
    OSBAPI_VERSION = File.read(File.expand_path('../../config/osbapi_version', File.dirname(__FILE__))).strip.freeze

    # This is an invalid parameter that the nginx-upload-module might pass through during
    # file uploads to Cloud Controller. Its presence signifies that something went awry
    # during the upload and that some of the required file path metadata is missing
    INVALID_NGINX_UPLOAD_PARAM = '<ngx_upload_module_dummy>'.freeze
  end
end
