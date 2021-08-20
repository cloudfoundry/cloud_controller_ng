module VCAP::CloudController
  class SecurityGroupFetcher
    class << self
      def fetch(guid, visible_security_group_guids=nil)
        dataset = SecurityGroup.where(guid: guid)
        dataset = dataset.where(guid: visible_security_group_guids) if visible_security_group_guids
        dataset = eager_load_running_and_staging_space_guids(dataset)
        dataset.all.first
      end

      def eager_load_running_and_staging_space_guids(dataset)
        select_guid = proc { |ds| ds.select(:guid) }
        dataset.eager(spaces: select_guid, staging_spaces: select_guid)
      end
    end
  end
end
