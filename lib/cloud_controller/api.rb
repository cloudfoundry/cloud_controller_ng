# Copyright (c) 2009-2012 VMware, Inc.

require "cloud_controller/access_controller"
require "cloud_controller/role"
require "cloud_controller/rest_controller"

module VCAP::CloudController
  define_role :CFAdmin
  define_role :OrgAdmin
  define_role :OrgMember
  define_role :AppSpaceMember
  define_role :Authenticated
  define_role :Anonymous
end

Dir[File.expand_path("../api/*", __FILE__)].each do |file|
  require file
end
