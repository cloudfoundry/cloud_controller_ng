require 'cloud_controller/copilot/adapter'

module VCAP::CloudController
  class RouteMappingModel < Sequel::Model(:route_mappings)
    DEFAULT_PROTOCOL_MAPPING = { 'tcp' => 'tcp', 'http' => 'http1' }.freeze
    VALID_PROTOCOLS = ['http1', 'http2', 'tcp'].freeze

    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid,
                      primary_key: :guid, without_guid_generation: true
    many_to_one :route, key: :route_guid, primary_key: :guid, without_guid_generation: true

    one_through_one :space, join_table: AppModel.table_name, left_key: :guid,
                            left_primary_key: :app_guid, right_primary_key: :guid, right_key: :space_guid

    many_to_one :process, class: 'VCAP::CloudController::ProcessModel',
      key: [:app_guid, :process_type], primary_key: [:app_guid, :type] do |dataset|
        dataset.order(Sequel.desc(:created_at), Sequel.desc(:id))
      end

    one_to_many :processes, class: 'VCAP::CloudController::ProcessModel',
      primary_key: [:app_guid, :process_type], key: [:app_guid, :type]

    def protocol_with_defaults=(new_protocol)
      self.protocol_without_defaults = (new_protocol == 'http2' ? new_protocol : nil)
    end

    alias_method :protocol_without_defaults=, :protocol=
    alias_method :protocol=, :protocol_with_defaults=

    def protocol_with_defaults
      self.protocol_without_defaults == 'http2' ? 'http2' : DEFAULT_PROTOCOL_MAPPING[self.route&.protocol]
    end

    alias_method :protocol_without_defaults, :protocol
    alias_method :protocol, :protocol_with_defaults

    def validate
      validates_presence [:app_port]
      validates_unique [:app_guid, :route_guid, :process_type, :app_port]

      validate_weight
    end

    def self.user_visibility_filter(user)
      { space: Space.user_visible(user) }
    end

    def after_destroy
      super

      db.after_commit do
        Copilot::Adapter.unmap_route(self)
      end
    end

    def adapted_weight
      self.weight || 1
    end

    def presented_port
      if has_app_port_specified?
        return app_port
      end

      app_droplet = app.droplet
      if app_droplet && app_droplet.docker_ports.any?
        return app_droplet.docker_ports.first
      end

      ProcessModel::DEFAULT_HTTP_PORT
    end

    def has_app_port_specified?
      app_port != ProcessModel::NO_APP_PORT_SPECIFIED
    end

    private

    def logger
      @logger ||= Steno.logger('cc.route_mapping')
    end

    def validate_weight
      return unless weight.present?

      errors.add(:weight, 'must be between 1 and 100') unless (1..100).member?(weight)
    end
  end
end
