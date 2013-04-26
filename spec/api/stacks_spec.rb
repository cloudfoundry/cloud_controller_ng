# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe Stack do
    it_behaves_like "a CloudController API", {
      :path                 => "/v2/stacks",
      :model                => Models::Stack,
      :read_only            => true,
      :basic_attributes     => [:name, :description],
      :required_attributes  => [:name, :description],
      :unique_attributes    => :name,
      :queryable_attributes => :name,
      :ci_attributes        => :name
    }
  end
end
