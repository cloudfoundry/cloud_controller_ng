module VCAP::CloudController
  class ServiceBrokerUpdateRequest < Sequel::Model
    one_to_one :service_broker
    set_field_as_encrypted :authentication

    one_to_many :labels, class: 'VCAP::CloudController::ServiceBrokerUpdateRequestLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::ServiceBrokerUpdateRequestAnnotationModel', key: :resource_guid, primary_key: :guid

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy
  end
end
