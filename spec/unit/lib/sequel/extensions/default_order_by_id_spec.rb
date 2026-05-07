# frozen_string_literal: true

require 'lightweight_db_spec_helper'
require 'sequel/extensions/default_order_by_id'

DB.extension(:sql_comments)
DB.extension(:default_order_by_id)

RSpec.describe 'Sequel::DefaultOrderById' do
  let(:db) { DB }

  let(:model_class) { Class.new(Sequel::Model(db[:test_default_order_main])) }

  before(:all) do
    DB.create_table?(:test_default_order_main) do
      primary_key :id
      String :name
      String :guid
      String :status
    end
    DB.create_table?(:test_default_order_join) do
      primary_key :id
      foreign_key :main_id, :test_default_order_main
    end
  end

  after(:all) do
    DB.drop_table?(:test_default_order_join)
    DB.drop_table?(:test_default_order_main)
  end

  def capture_sql(&)
    sqls = []
    db.loggers << (logger = Class.new do
      define_method(:info) { |msg| sqls << msg if msg.include?('SELECT') }
      define_method(:debug) { |_| }
      define_method(:error) { |_| }
    end.new)
    yield
    sqls.last
  ensure
    db.loggers.delete(logger)
  end

  describe 'default ordering' do
    it 'adds ORDER BY id to model queries' do
      sql = capture_sql { model_class.dataset.all }
      expect(sql).to match(/ORDER BY .id./)
    end

    it 'annotates queries with an SQL comment' do
      sql = capture_sql { model_class.dataset.all }
      expect(sql).to include('-- default_order_by_id')
    end
  end

  describe 'already_ordered?' do
    it 'preserves explicit ORDER BY' do
      sql = capture_sql { model_class.dataset.order(:name).all }
      expect(sql).to match(/ORDER BY .name./)
    end
  end

  describe 'incompatible_with_order?' do
    it 'skips for GROUP BY' do
      sql = capture_sql { model_class.dataset.select_group(:status).select_append(Sequel.function(:max, :id).as(:id)).all }
      expect(sql).not_to match(/ORDER BY/)
    end

    it 'skips for compound queries (UNION)' do
      ds1 = model_class.dataset.where(name: 'a')
      ds2 = model_class.dataset.where(name: 'b')
      sql = capture_sql { ds1.union(ds2, all: true, from_self: false).all }
      expect(sql).not_to match(/ORDER BY/)
    end

    it 'skips for DISTINCT ON' do
      skip if db.database_type != :postgres

      sql = capture_sql { model_class.dataset.distinct(:guid).all }
      expect(sql).not_to match(/ORDER BY/)
    end

    it 'skips for from_self (subquery)' do
      sql = capture_sql { model_class.dataset.where(name: 'a').from_self.all }
      expect(sql).not_to match(/ORDER BY/)
    end

    it 'does not skip for table alias' do
      sql = capture_sql { model_class.dataset.from(Sequel[:test_default_order_main].as(:aliased_table)).all }
      expect(sql).to match(/ORDER BY .id./)
    end
  end

  describe 'not_a_data_query?' do
    it 'skips for schema introspection (columns!)' do
      sql = capture_sql { model_class.dataset.columns! }
      expect(sql).not_to match(/ORDER BY/)
    end
  end

  describe 'model_has_id_primary_key?' do
    it 'skips for models with non-id primary key' do
      guid_pk_model = Class.new(Sequel::Model(db[:test_default_order_main])) do
        set_primary_key :guid
      end
      sql = capture_sql { guid_pk_model.dataset.all }
      expect(sql).not_to match(/ORDER BY/)
    end
  end

  describe 'find_id_column' do
    context 'with SELECT *' do
      it 'uses unqualified :id' do
        sql = capture_sql { model_class.dataset.all }
        expect(sql).to match(/ORDER BY .id./)
      end

      it 'uses qualified column for JOIN to avoid ambiguity' do
        sql = capture_sql { model_class.dataset.join(:test_default_order_join, main_id: :id).all }
        expect(sql).to match(/ORDER BY .test_default_order_main.\..id./)
      end
    end

    context 'with SELECT table.*' do
      it 'uses unqualified :id' do
        sql = capture_sql { model_class.dataset.select(Sequel::SQL::ColumnAll.new(:test_default_order_main)).join(:test_default_order_join, main_id: :id).all }
        expect(sql).to match(/ORDER BY .id./)
      end
    end

    context 'with qualified id in select list' do
      it 'uses the qualified column' do
        qualified_id = Sequel.qualify(:test_default_order_main, :id)
        qualified_name = Sequel.qualify(:test_default_order_main, :name)
        sql = capture_sql { model_class.dataset.select(qualified_id, qualified_name).all }
        expect(sql).to match(/ORDER BY .test_default_order_main.\..id./)
      end
    end

    context 'with aliased id in select list' do
      it 'uses the alias' do
        qualified_id = Sequel.qualify(:test_default_order_main, :id)
        sql = capture_sql { model_class.dataset.select(Sequel.as(qualified_id, :order_id), :name).all }
        expect(sql).to match(/ORDER BY .order_id./)
      end
    end

    context 'without id in select list' do
      it 'skips ordering' do
        sql = capture_sql { model_class.dataset.select(:guid, :name).all }
        expect(sql).not_to match(/ORDER BY/)
      end
    end
  end

  describe 'association loading (placeholder_literalizer_loader)' do
    let(:child_class) { Class.new(Sequel::Model(db[:test_default_order_join])) }

    it 'adds ORDER BY id to association queries' do
      child = child_class
      parent_class = Class.new(Sequel::Model(db[:test_default_order_main])) do
        define_singleton_method(:name) { 'TestParent' } # vcap_relations plugin derives reciprocal from self.name
        one_to_many :children, class: child, key: :main_id
      end
      parent = parent_class.new
      parent.values[:id] = 1
      sql = capture_sql { parent.children }
      expect(sql).to match(/ORDER BY .id./)
    end

    it 'does not override explicit association order' do
      child = child_class
      parent_class = Class.new(Sequel::Model(db[:test_default_order_main])) do
        define_singleton_method(:name) { 'TestParent' }
        one_to_many :children, class: child, key: :main_id, order: Sequel.desc(:id)
      end
      parent = parent_class.new
      parent.values[:id] = 1
      sql = capture_sql { parent.children }
      expect(sql).to match(/ORDER BY .id. DESC/)
    end
  end
end
