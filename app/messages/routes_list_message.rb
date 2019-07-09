require 'messages/list_message'

module VCAP::CloudController
  class RoutesListMessage < ListMessage
    register_allowed_keys [
      :hosts,
      :space_guids,
      :organization_guids,
      :domain_guids,
      :paths,
      :label_selector,
    ]

    validates_with NoAdditionalParamsValidator

    validates :hosts, allow_nil: true, array: true
    validates :paths, allow_nil: true, array: true
    validates :space_guids, allow_nil: true, array: true
    validates :organization_guids, allow_nil: true, array: true
    validates :domain_guids, allow_nil: true, array: true

    attr_reader :app_guid

    def self.from_params(params)
      message = super(params, %w(hosts space_guids organization_guids domain_guids paths))
      if message.requested?(:hosts) && message.hosts.empty?
        message.hosts.push('')
      end
      if message.requested?(:paths) && message.paths.empty?
        message.paths.push('')
      end
      message
    end

    def for_app_guid(app_guid)
      @app_guid = app_guid
      self
    end
  end
end
