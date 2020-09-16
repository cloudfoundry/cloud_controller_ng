require 'access/base_access'
require 'controllers/base/model_controller'

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

  class TestModelAccess < BaseAccess
    # Only if the token has the appropriate scope, use these methods to check if the user is authorized to access the resource

    def create?(object, params=nil)
      admin_user?
    end

    def read?(object)
      return @ok_read if instance_variable_defined?(:@ok_read)

      @ok_read = (admin_user? || admin_read_only_user? || global_auditor? || object_is_visible_to_user?(object, context.user))
    end

    def read_for_update?(object, params=nil)
      admin_user?
    end

    def can_remove_related_object?(object, params=nil)
      read_for_update?(object, params)
    end

    def read_related_object_for_update?(object, params=nil)
      read_for_update?(object, params)
    end

    def update?(object, params=nil)
      admin_user?
    end

    def delete?(object)
      admin_user?
    end

    def index?(object_class, params=nil)
      # This can return true because the index endpoints filter objects based on user visibilities
      true
    end

    # These methods should be called first to determine if the user's token has the appropriate scope for the operation

    def read_with_token?(_)
      admin_user? || admin_read_only_user? || has_read_scope? || global_auditor?
    end

    def create_with_token?(_)
      admin_user? || has_write_scope?
    end

    def read_for_update_with_token?(_)
      admin_user? || has_write_scope?
    end

    def can_remove_related_object_with_token?(*args)
      read_for_update_with_token?(*args)
    end

    def read_related_object_for_update_with_token?(*args)
      read_for_update_with_token?(*args)
    end

    def update_with_token?(_)
      admin_user? || has_write_scope?
    end

    def delete_with_token?(_)
      admin_user? || has_write_scope?
    end

    def index_with_token?(_)
      # This can return true because the index endpoints filter objects based on user visibilities
      true
    end
  end

  class TestModelDestroyDepAccess < TestModelAccess; end
  class TestModelNullifyDepAccess < TestModelAccess; end
  class TestModelManyToOneAccess < TestModelAccess; end
  class TestModelManyToManyAccess < TestModelAccess; end

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

  class TestModelRedactAccess < TestModelAccess; end

  class TestModelRedactController < RestController::ModelController
    define_attributes do
      attribute :redacted, Hash, redact_in: [:create, :update]
    end

    define_messages
    define_routes
  end
end
