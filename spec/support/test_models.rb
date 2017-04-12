module VCAP::CloudController
  class TestModelDestroyDep < Sequel::Model; end
  class TestModelNullifyDep < Sequel::Model; end
  class TestModelManyToOne < Sequel::Model
    many_to_one :test_model
    export_attributes :test_model_guid
  end
  class TestModelManyToMany < Sequel::Model
    one_to_many :test_model_second_levels
  end
  class TestModelSecondLevel < Sequel::Model
    many_to_one :test_model_many_to_many
  end

  class TestModel < Sequel::Model
    one_to_many :test_model_destroy_deps
    one_to_many :test_model_nullify_deps
    one_to_many :test_model_many_to_ones
    many_to_many :test_model_many_to_manies, join_table: :test_model_m_to_m_test_models

    add_association_dependencies(test_model_destroy_deps: :destroy,
                                 test_model_nullify_deps: :nullify)

    import_attributes :required_attr, :unique_value, :test_model_many_to_many_guids
    export_attributes :unique_value, :sortable_value, :nonsortable_value

    def validate
      validates_unique :unique_value
    end
  end

  class TestModelAccess < BaseAccess; end
  class TestModelDestroyDepAccess < BaseAccess; end
  class TestModelNullifyDepAccess < BaseAccess; end
  class TestModelManyToOneAccess < BaseAccess; end
  class TestModelManyToManyAccess < BaseAccess; end

  class TestModelsController < RestController::ModelController
    define_attributes do
      attribute :required_attr, TrueClass
      attribute :unique_value, String
      to_many :test_model_many_to_ones
      to_many :test_model_many_to_manies
      to_many :test_model_many_to_manies_link_only, association_name: :test_model_many_to_manies, link_only: true
    end

    query_parameters :unique_value, :created_at
    sortable_parameters :sortable_value

    define_messages
    define_routes

    def delete(guid)
      obj = find_guid(guid)
      validate_access(:delete, obj)
      do_delete(obj)
    end

    def self.translate_validation_exception(_, attributes)
      CloudController::Errors::ApiError.new_from_details('TestModelValidation', attributes['unique_value'])
    end
  end

  class TestModelManyToOnesController < RestController::ModelController
    define_attributes do
      to_one :test_model
    end

    define_messages
    define_routes
  end

  class TestModelManyToManiesController < RestController::ModelController
    define_attributes do
      to_many :test_model_second_levels
    end

    define_messages
    define_routes
  end

  class TestModelLinkOnliesController < RestController::ModelController
  end

  class TestModelSecondLevelsController < RestController::ModelController
  end

  class TestModelRedact < Sequel::Model
    import_attributes :redacted
    export_attributes :redacted
  end

  class TestModelRedactAccess < BaseAccess; end

  class TestModelRedactController < RestController::ModelController
    define_attributes do
      # TODO: see comment in model_controller_spec around MSSQL and hashes
      # attribute :redacted, Hash, redact_in: [:create, :update]
      attribute :redacted, String, redact_in: [:create, :update]
    end

    define_messages
    define_routes
  end
end
