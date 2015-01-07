class FakeModelTables
  def initialize(db)
    @db = db
  end

  def create_tables
    tables_for_model_controller_spec
    tables_for_vcap_relations_spec
    tables_for_sequel_case_insensitive_string_monkeypatch
    tables_for_query_spec
  end

  def tables_for_model_controller_spec
    db.create_table :test_models do
      primary_key :id
      String :guid
      String :unique_value
      TrueClass :required_attr, null: false
      DateTime :created_at
      DateTime :updated_at
    end

    db.create_table :test_model_destroy_deps do
      primary_key :id
      String :guid
      Integer :test_model_id
      foreign_key [:test_model_id], :test_models, name: :fk_test_model_id_destroy_deps
    end

    db.create_table :test_model_nullify_deps do
      primary_key :id
      String :guid
      Integer :test_model_id
      foreign_key [:test_model_id], :test_models, name: :fk_test_model_id_nullify_deps
    end

    db.create_table :test_model_many_to_ones do
      primary_key :id
      String :guid
      Integer :test_model_id
      String :value
      DateTime :created_at
    end

    db.create_table :test_model_many_to_manies do
      primary_key :id
      String :guid
      String :value
      DateTime :created_at
    end

    db.create_table :test_model_second_levels do
      primary_key :id
      String :guid
      Integer :test_model_many_to_many_id
      DateTime :created_at
    end

    db.create_table :test_model_m_to_m_test_models do
      primary_key :id
      Integer :test_model_id
      Integer :test_model_many_to_many_id
      foreign_key [:test_model_id], :test_models, name: :fk_tmmtmtm_tmi
      foreign_key [:test_model_many_to_many_id], :test_model_many_to_manies, name: :fk_tmmtmtm_tmmtmi
    end
  end

  def tables_for_vcap_relations_spec
    db.create_table :owners do
      primary_key :id
      String :guid, null: false, index: true
    end

    db.create_table :dogs do
      primary_key :id
      String :guid, null: false, index: true

      # a dog has an owner, (but allowing null, it may be a stray)
      foreign_key :owner_id, :owners
    end

    db.create_table :names do
      primary_key :id
      String :guid, null: false, index: true
    end

    # contrived example.. there is a many-to-many relationship between a dog
    # and a name, i.e. the main name plus all the nick names a dog can go by
    db.create_table :dogs_names do
      foreign_key :dog_id, :dogs, null: false
      foreign_key :name_id, :names, null: false

      # needed to expose the many_to_many add flaw in native Sequel
      index [:dog_id, :name_id], unique: true, name: 'dog_id_name_id_idx'
    end

    db.create_table :tops do
      primary_key :id
    end

    db.create_table :middles do
      primary_key :id
      String :guid, null: false, index: true
      foreign_key :top_id, :tops
    end

    db.create_table :bottoms do
      primary_key :id
      foreign_key :middle_id, :middles
    end
  end

  def tables_for_sequel_case_insensitive_string_monkeypatch
    db.create_table :unique_str_defaults do
      primary_key :id
      String :str, unique: true
    end

    db.create_table :unique_str_case_sensitive do
      primary_key :id
      String :str, case_insensitive: false
      index [:str], unique: true, name: 'uniq_str_sensitive'
    end

    db.create_table :unique_str_case_insensitive do
      primary_key :id
      String :str, case_insensitive: true
      index [:str], unique: true, name: 'uniq_str_insensitive'
    end

    db.create_table :unique_str_altered do
      primary_key :id
      String :altered_to_default
      String :altered_to_case_sensitive
      String :altered_to_case_insensitive

      index [:altered_to_default], unique: true, name: 'uniq_str_altered_1'
      index [:altered_to_case_sensitive], unique: true, name: 'uniq_str_altered_2'
      index [:altered_to_case_insensitive], unique: true, name: 'uniq_str_altered_3'
    end

    db.alter_table :unique_str_altered do
      set_column_type :altered_to_default, String
      set_column_type :altered_to_case_sensitive, String, case_insensitive: false
      set_column_type :altered_to_case_insensitive, String, case_insensitive: true
    end
  end

  def tables_for_query_spec
    db.create_table :authors do
      primary_key :id

      Integer :num_val
      String :str_val
      Integer :protected
      Boolean :published
      DateTime :published_at
    end

    db.create_table :books do
      primary_key :id

      Integer :num_val
      String :str_val

      foreign_key :author_id, :authors
    end

    db.create_table :magazines do
      primary_key :id

      String :guid
    end

    db.create_table :subscribers do
      primary_key :id

      String :guid

      foreign_key :magazine_id, :magazines
    end
  end

  private

  attr_reader :db
end
