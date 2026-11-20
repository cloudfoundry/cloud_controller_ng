module VCAP::CloudController
  class ServiceAccountLabelModel < Sequel::Model(:service_account_labels)
    many_to_one :service_account, class: 'VCAP::CloudController::ServiceAccountModel', primary_key: :guid, key: :resource_guid, without_guid_generation: true
    include MetadataModelMixin
  end
end
