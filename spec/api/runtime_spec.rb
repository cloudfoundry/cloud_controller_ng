# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe Runtime do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/runtimes",
    :model                => VCAP::CloudController::Models::Runtime,
    :basic_attributes     => [:name, :description],
    :required_attributes  => [:name, :description],
    :unique_attributes    => :name,
    :one_to_many_collection_ids => {
      :apps  => lambda { |framework| VCAP::CloudController::Models::App.make }
    }
  }

end
end
