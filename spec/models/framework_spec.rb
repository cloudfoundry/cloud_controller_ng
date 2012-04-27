# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::Framework do
  it_behaves_like "a CloudController model", {
    :required_attributes        => [:name, :description],
    :unique_attributes          => :name,
    :stripped_string_attributes => :name,
    :one_to_zero_or_more => {
      :apps => lambda { |service_binding| VCAP::CloudController::Models::App.make }
    }
  }

end
