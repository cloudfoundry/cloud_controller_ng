# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Organization do
    it_behaves_like "a CloudController model", {
      :required_attributes          => :name,
      :unique_attributes            => :name,
      :stripped_string_attributes   => :name,
      :many_to_zero_or_more => {
        :users      => lambda { |org| Models::User.make },
        :managers   => lambda { |org| Models::User.make },
        :billing_managers => lambda { |org| Models::User.make },
        :auditors   => lambda { |org| Models::User.make },
      },
      :one_to_zero_or_more => {
        :spaces  => lambda { |org| Models::Space.make },
        :domains => lambda { |org|
          Models::Domain.make(:owning_organization => org)
        }
      }
    }

    describe "default domains" do
      context "with the default serving domain name set" do
        before do
          Models::Domain.default_serving_domain_name = "foo.com"
        end

        after do
          Models::Domain.default_serving_domain_name = nil
        end

        it "should be associated with the default serving domain" do
          org = Models::Organization.make
          d = Models::Domain.default_serving_domain
          org.domains.map(&:guid) == [d.guid]
        end
      end
    end
  end
end
