# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::App do
  let(:app_obj) { VCAP::CloudController::Models::App.make }
  let(:app_space) { VCAP::CloudController::Models::AppSpace.make }
  let(:runtime) { VCAP::CloudController::Models::Runtime.make }
  let(:framework) { VCAP::CloudController::Models::Framework.make }

  it_behaves_like "an authenticated CloudController API",
    VCAP::CloudController::Models::App,
    [
      ['/v2/apps', :post, 201, 403, 401, { :name => Sham.name, :app_space_id => '#{app_space.id}', :runtime_id => '#{runtime.id}', :framework_id => '#{framework.id}' } ],
      ['/v2/apps', :get, 200, 403, 401],
      ['/v2/apps/#{app_obj.id}', :put, 201, 403, 401, { :name => '#{app_obj.name}_renamed' }],
      ['/v2/apps/#{app_obj.id}', :delete, 204, 403, 401],
    ]

  # FIXME: make app_space_id a relation check that checks the id and the url
  # part.  do everywhere
  it_behaves_like "a CloudController API", {
    :path                => '/v2/apps',
    :model               => VCAP::CloudController::Models::App,
    :basic_attributes    => [:name, :app_space_id, :runtime_id, :framework_id],
    :required_attributes => [:name, :app_space_id, :runtime_id, :framework_id],
    :unique_attributes   => [:name, :app_space_id],

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
