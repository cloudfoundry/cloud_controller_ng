# Copyright (c) 2009-2012 VMware, Inc.

require "cloud_controller/rest_controller"

Dir[File.expand_path("../api/*", __FILE__)].each do |file|
  require file
end
