require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/label_selector_query_generator'

module VCAP::CloudController
  class EventListFetcher
    class << self
      def fetch_all(message, event_dataset)
        filter(message, event_dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:types)
          dataset = dataset.where(type: message.types)
        end

        if message.requested?(:target_guids)
          dataset = dataset.where(actee: message.target_guids)
        end

        if message.requested?(:space_guids)
          dataset = dataset.where(space_guid: message.space_guids)
        end

        if message.requested?(:organization_guids)
          dataset = dataset.where(organization_guid: message.organization_guids)
        end

        if message.requested?(:created_ats)
          if message.gt_params.include?('created_ats')
            created_at = message.created_ats.first
            dataset = dataset.where { timestamp > Time.at(Time.parse(created_at).utc + 0.99999).utc }
          elsif message.lt_params.include?('created_ats')
            created_at = message.created_ats.first
            dataset = dataset.where { timestamp < Time.parse(created_at).utc }
          else
            blah = message.created_ats.collect do |created_at_string|
              lower_bound = Time.parse(created_at_string).utc
              upper_bound = Time.at(lower_bound + 0.99999).utc
              [:timestamp, (lower_bound...upper_bound)]
            end
            dataset = dataset.where(Sequel.or(blah))
          end
        end

        dataset
      end
    end
  end
end
