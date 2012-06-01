# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Framework do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/frameworks",
    :model                => VCAP::CloudController::Models::Framework,
    :basic_attributes     => [:name, :description],
    :required_attributes  => [:name, :description],
    :unique_attributes    => :name,
    :one_to_many_collection_ids => {
      :apps  => lambda { |framework| VCAP::CloudController::Models::App.make }
    }
  }

end
