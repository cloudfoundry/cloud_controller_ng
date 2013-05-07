# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::QuotaDefinition do

    include_examples "uaa authenticated api", path: "/v2/quota_definitions"
    include_examples "enumerating objects", path: "/v2/quota_definitions", model: Models::QuotaDefinition
    include_examples "reading a valid object", path: "/v2/quota_definitions", model: Models::QuotaDefinition, basic_attributes: %w(name non_basic_services_allowed total_services memory_limit free_rds)
    include_examples "operations on an invalid object", path: "/v2/quota_definitions"
    include_examples "creating and updating", path: "/v2/quota_definitions", model: Models::QuotaDefinition, required_attributes: %w(name non_basic_services_allowed total_services memory_limit), unique_attributes: %w(name), ci_attributes: %w(name), extra_attributes: []
    include_examples "deleting a valid object", path: "/v2/quota_definitions", model: Models::QuotaDefinition, one_to_many_collection_ids: {},
      one_to_many_collection_ids_without_url: {
        :organizations => lambda { |quota_definition|
          Models::Organization.make(:quota_definition => quota_definition)
        }
      }
    include_examples "collection operations", path: "/v2/quota_definitions", model: Models::QuotaDefinition,
      one_to_many_collection_ids: {},
      one_to_many_collection_ids_without_url: {
        organizations: lambda { |quota_definition| Models::Organization.make(quota_definition: quota_definition) }
      },
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {}
  end
end
