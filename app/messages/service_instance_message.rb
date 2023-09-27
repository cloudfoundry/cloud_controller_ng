require 'messages/metadata_base_message'
require 'presenters/helpers/censorship'

module VCAP
  module CloudController
    class ServiceInstanceMessage < MetadataBaseMessage
      def audit_hash
        super.tap do |h|
          h['credentials'] = VCAP::CloudController::Presenters::Censorship::PRIVATE_DATA_HIDDEN if h['credentials'].present?
        end
      end
    end
  end
end
