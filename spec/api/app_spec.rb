# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe App do

  let(:app_obj) { VCAP::CloudController::Models::App.make }
  let(:app_space) { VCAP::CloudController::Models::AppSpace.make }
  let(:runtime) { VCAP::CloudController::Models::Runtime.make }
  let(:framework) { VCAP::CloudController::Models::Framework.make }

  # FIXME: make app_space_id a relation check that checks the id and the url
  # part.  do everywhere
  it_behaves_like "a CloudController API", {
    :path                => "/v2/apps",
    :model               => VCAP::CloudController::Models::App,
    :basic_attributes    => [:name, :app_space_guid, :runtime_guid, :framework_guid],
    :required_attributes => [:name, :app_space_guid, :runtime_guid, :framework_guid],
    :unique_attributes   => [:name, :app_space_guid],

    :many_to_one_collection_ids => {
      :app_space       => lambda { |app| VCAP::CloudController::Models::AppSpace.make  },
      :framework       => lambda { |app| VCAP::CloudController::Models::Framework.make },
      :runtime         => lambda { |app| VCAP::CloudController::Models::Runtime.make   }
    },
    :one_to_many_collection_ids  => {
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
