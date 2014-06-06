class FakeModelTables
  def initialize(db)
    @db = db
  end

  def create_tables
    db.create_table :test_models do
      primary_key :id
      String :guid
      String :value
      Date :created_at
      Date :updated_at
    end

    db.create_table :test_model_destroy_deps do
      primary_key :id
      String :guid
      Integer :test_model_id
      foreign_key [:test_model_id], :test_models, :name => :fk_test_model_id_destroy_deps
    end

    db.create_table :test_model_nullify_deps do
      primary_key :id
      String :guid
      Integer :test_model_id
      foreign_key [:test_model_id], :test_models, :name => :fk_test_model_id_nullify_deps
    end
  end

  private

  attr_reader :db
end
