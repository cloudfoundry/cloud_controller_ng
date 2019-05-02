module VCAP::CloudController
  class DomainLabelModel < Sequel::Model(:domain_labels)
    many_to_one :domain,
      class: 'VCAP::CloudController::DomainModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
