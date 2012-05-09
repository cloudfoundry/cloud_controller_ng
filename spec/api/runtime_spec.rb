# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::Runtime do
  let(:runtime) { VCAP::CloudController::Models::Runtime.make }

  it_behaves_like "a CloudController API", {
    :path                 => '/v2/runtimes',
    :model                => VCAP::CloudController::Models::Runtime,
    :basic_attributes     => [:name, :description],
    :required_attributes  => [:name, :description],
    :unique_attributes    => :name,
    :one_to_many_collection_ids => {
      :apps  => lambda { |framework| VCAP::CloudController::Models::App.make }
    }
  }

  it_behaves_like "an authenticated CloudController API",
    VCAP::CloudController::Models::Runtime,
    [
      ['/v2/runtimes', :post, 201, 403, 401, { :name => Sham.label, :description => Sham.description }],
      ['/v2/runtimes', :get, 200, 403, 401],
      ['/v2/runtimes/#{runtime.id}', :put, 201, 403, 401, { :name => Sham.name }],
      ['/v2/runtimes/#{runtime.id}', :delete, 204, 403, 401],
    ]

end
