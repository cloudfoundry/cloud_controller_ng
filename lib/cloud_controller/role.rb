# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController
  module Role; end

  def self.define_role(name)
    Role.const_set(name, Module.new)
  end
end
