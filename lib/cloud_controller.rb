# Copyright (c) 2009-2012 VMware, Inc.

require "bcrypt"
require "sequel"
require "vcap/logging"

require "cloud_controller/db"

module VCAP
  module CloudController;
    autoload :Models, "cloud_controller/models"
  end
end
