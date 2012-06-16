# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe Models::App do
  it_behaves_like "a CloudController model", {
    :required_attributes  => [:name, :framework, :runtime, :app_space],
    :unique_attributes    => [:app_space, :name],
    :stripped_string_attributes => :name,
    :many_to_one => {
      :app_space          => lambda { |app| VCAP::CloudController::Models::AppSpace.make  },
      :framework          => lambda { |app| VCAP::CloudController::Models::Framework.make },
      :runtime            => lambda { |app| VCAP::CloudController::Models::Runtime.make   }
    },
    :one_to_zero_or_more  => {
      :service_bindings   =>
       lambda { |app|
          service_binding = VCAP::CloudController::Models::ServiceBinding.make
          service_binding.service_instance.app_space = app.app_space
          service_binding
       }
    }
  }
end
end
