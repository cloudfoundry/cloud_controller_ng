# Copyright (c) 2009-2012 VMware, Inc.
require "vcap/rest_api/errors"

module VCAP::Errors
  include VCAP::RestAPI::Errors

  ERRORS_DIR = File.expand_path("../../../vendor/errors", __FILE__)

  YAML.load_file("#{ERRORS_DIR}/v2.yml").each do |code, meta|
    define_error meta["name"], meta["http_code"], code, meta["message"]
  end
end
