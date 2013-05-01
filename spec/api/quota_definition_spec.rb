# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::QuotaDefinition do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/quota_definitions",
      :model                => Models::QuotaDefinition,
      :basic_attributes     => [:name, :non_basic_services_allowed,
                                :total_services, :memory_limit],
      :required_attributes  => [:name, :non_basic_services_allowed,
                                :total_services, :memory_limit],
      :unique_attributes    => :name,
      :one_to_many_collection_ids_without_url => {
        :organizations => lambda { |quota_definition|
          Models::Organization.make(:quota_definition => quota_definition)
        }
      }
    }

    include_examples "uaa authenticated api", path: "/v2/quota_definitions"
    include_examples "enumerating objects", path: "/v2/quota_definitions", model: Models::QuotaDefinition
    include_examples "reading a valid object", path: "/v2/quota_definitions", model: Models::QuotaDefinition, basic_attributes: [:name, :non_basic_services_allowed, :total_services, :memory_limit]
  end
end
