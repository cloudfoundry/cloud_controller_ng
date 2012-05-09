# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::Service do
  let(:service)   { VCAP::CloudController::Models::Service.make }

  it_behaves_like "a CloudController API", {
    :path                 => '/v2/services',
    :model                => VCAP::CloudController::Models::Service,
    :basic_attributes     => [:label, :provider, :url, :type, :description, :version, :info_url],
    :required_attributes  => [:label, :provider, :url, :type, :description, :version],
    :unique_attributes    => [:label, :provider],
    :one_to_many_collection_ids  => {
      :service_plans => lambda { |service| VCAP::CloudController::Models::ServicePlan.make }
    }
  }

  it_behaves_like "an authenticated CloudController API",
    VCAP::CloudController::Models::Service,
    [
      ['/v2/services', :post, 201, 403, 401, { :label => Sham.name, :provider => Sham.provider,
                                               :url => Sham.url, :type => Sham.type,
                                               :description => Sham.description, :version => Sham.version }],
      ['/v2/services', :get, 200, 403, 401],
      ['/v2/services/#{service.id}', :put, 201, 403, 401, { :label => '#{service.label}_renamed' }],
      ['/v2/services/#{service.id}', :delete, 204, 403, 401],
    ]

end
