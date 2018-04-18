require 'messages/list_message'

module VCAP::CloudController
  class ServiceBindingsListMessage < ListMessage
    register_allowed_keys [:app_guids, :service_instance_guids, :order_by, :page, :per_page]

    validates_with NoAdditionalParamsValidator

    def self.from_params(params)
      opts = params.dup

      %w(app_guids service_instance_guids).each do |key|
        to_array!(opts, key)
      end

      new(opts.symbolize_keys)
    end
  end
end
