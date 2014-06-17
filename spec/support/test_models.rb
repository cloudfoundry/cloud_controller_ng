module VCAP::CloudController
  class TestModelDestroyDep < Sequel::Model; end
  class TestModelNullifyDep < Sequel::Model; end
  class TestModelManyToOne < Sequel::Model
    many_to_one :test_model
    export_attributes :test_model_guid
  end
  class TestModelManyToMany < Sequel::Model; end

  class TestModel < Sequel::Model
    one_to_many :test_model_destroy_deps
    one_to_many :test_model_nullify_deps
    one_to_many :test_model_many_to_ones
    many_to_many :test_model_many_to_manies

    add_association_dependencies(:test_model_destroy_deps => :destroy,
                                 :test_model_nullify_deps => :nullify)

    import_attributes :required_attr, :unique_value, :test_model_many_to_many_guids
    export_attributes :unique_value

    def validate
      validates_unique :unique_value
    end
  end

  class TestModelAccess < BaseAccess; end
  class TestModelDestroyDepAccess < BaseAccess; end
  class TestModelNullifyDepAccess < BaseAccess; end
  class TestModelManyToOneAccess < BaseAccess; end
end
