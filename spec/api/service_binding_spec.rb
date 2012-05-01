# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::ServiceBinding do
  let(:service_binding) { VCAP::CloudController::Models::ServiceBinding.make }
  let(:app_obj) { VCAP::CloudController::Models::App.make }

  it_behaves_like "a CloudController API", {
    :path                 => '/v2/service_bindings',
    :model                => VCAP::CloudController::Models::ServiceBinding,
    :basic_attributes     => [:credentials, :binding_options, :vendor_data, :app_id, :service_instance_id],
    :required_attributes  => [:credentials, :app_id, :service_instance_id],
    :unique_attributes    => [:app_id, :service_instance_id]
  }

  it_behaves_like "an authenticated CloudController API",
    VCAP::CloudController::Models::ServiceInstance,
    [
      ['/v2/service_bindings', :post, 201, 403, 401, { :credentials         => Sham.service_credentials,
                                                      :app_id              => '#{app_obj.id}',
                                                      :app_space_id        => '#{app_obj.app_space_id}',
                                                      :service_instance_id => '#{service_binding.id}' } ],
      ['/v2/service_bindings', :get, 200, 403, 401],
      ['/v2/service_bindings/#{service_binding.id}', :put, 201, 403, 401, { :credentials => Sham.service_credentials }],
      ['/v2/service_bindings/#{service_binding.id}', :delete, 204, 403, 401],
    ]

end
