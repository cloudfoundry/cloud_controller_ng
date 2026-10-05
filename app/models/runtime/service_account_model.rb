module VCAP::CloudController
  class ServiceAccountModel < Sequel::Model(:service_accounts)
    NAME_PATTERN = /\A[a-z0-9][a-z0-9-]{1,61}[a-z0-9]\z/

    many_to_one :space, key: :space_guid, primary_key: :guid, without_guid_generation: true
    one_to_many :apps, class: 'VCAP::CloudController::AppModel', key: :service_account_guid, primary_key: :guid
    one_to_many :labels, class: 'VCAP::CloudController::ServiceAccountLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::ServiceAccountAnnotationModel', key: :resource_guid, primary_key: :guid
    add_association_dependencies labels: :destroy, annotations: :destroy

    def validate
      super
      validates_presence :space
      validates_format NAME_PATTERN, :name
      errors.add(:name, 'is immutable') if !new? && column_changed?(:name)
      errors.add(:space, 'is immutable') if !new? && column_changed?(:space_guid)
    end

    def around_create
      db.transaction(savepoint: true) do
        # Keep this reservation permanently, even when the account is destroyed.
        # The unique constraint, rather than a preflight query, serializes claims.
        db[:service_account_names].insert(name: name) # rubocop:disable Rails/SkipsModelValidations -- Atomic namespace reservation, not an ActiveRecord model.
        yield
      end
    rescue Sequel::UniqueConstraintViolation
      errors.add(:name, 'is already reserved')
      raise validation_failed_error
    end

    def client_id
      "cf:service-account:#{name}"
    end

    def certificate_dns_san
      "#{name}.svc.identity"
    end
  end
end
