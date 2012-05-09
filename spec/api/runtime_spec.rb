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

end
