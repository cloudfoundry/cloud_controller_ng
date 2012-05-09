# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::Framework do
  let(:framework) { VCAP::CloudController::Models::Framework.make }

  it_behaves_like "a CloudController API", {
    :path                 => '/v2/frameworks',
    :model                => VCAP::CloudController::Models::Framework,
    :basic_attributes     => [:name, :description],
    :required_attributes  => [:name, :description],
    :unique_attributes    => :name,
    :one_to_many_collection_ids => {
      :apps  => lambda { |framework| VCAP::CloudController::Models::App.make }
    }
  }

  it_behaves_like "an authenticated CloudController API",
    VCAP::CloudController::Models::Framework,
    [
      ['/v2/frameworks', :post, 201, 403, 401, { :name => Sham.label, :description => Sham.description }],
      ['/v2/frameworks', :get, 200, 403, 401],
      ['/v2/frameworks/#{framework.id}', :put, 201, 403, 401, { :name => Sham.name }],
      ['/v2/frameworks/#{framework.id}', :delete, 204, 403, 401]
    ]

end
