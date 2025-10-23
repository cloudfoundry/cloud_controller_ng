require 'spec_helper'

RSpec.describe 'Sequel::Plugins::VcapRelations' do
  def define_model(name)
    # we need new classes each time to reset the class level state
    model_klass = Class.new(Sequel::Model) do
      plugin :vcap_relations
      plugin :vcap_guid
    end
    stub_const(name.to_s, model_klass)
    model_klass.set_dataset(DbConfig.new.connection[:"#{name.downcase}s"])
  end

  let!(:owner_klass)  { define_model(:Owner) }
  let!(:dog_klass)    { define_model(:Dog) }
  let!(:name_klass)   { define_model(:Name) }
  let!(:top_klass)    { define_model(:Top) }
  let!(:middle_klass) { define_model(:Middle) }
  let!(:bottom_klass) { define_model(:Bottom) }

  describe '.one_to_many' do
    before do
      @o = owner_klass.create
      expect { @o.dogs }.to raise_error(NoMethodError)
      owner_klass.one_to_many :dogs
    end

    it 'adds a <relation> method' do
      expect(@o.dogs).to be_empty
    end

    it 'adds a add_<relation> method that takes an object' do
      d = dog_klass.create
      @o.add_dog d
      expect(@o.dogs).to include(d)
    end

    it 'adds a add_<relation> method that takes an id' do
      d = dog_klass.create
      @o.add_dog d.id
      d.refresh
      expect(@o.dogs).to include(d)
    end

    it 'adds a <relation>_ids= method that takes an array of ids' do
      d1 = dog_klass.create
      d2 = dog_klass.create

      @o.dog_ids = [d1.id, d2.id]
      d1.refresh
      d2.refresh
      expect(@o.dogs).to include(d1)
      expect(@o.dogs).to include(d2)

      @o.dog_ids = [d2.id]
      d1.refresh
      d2.refresh
      expect(@o.dogs).not_to include(d1)
      expect(@o.dogs).to include(d2)
    end

    it 'adds a add_<relation>_guids= method that takes a guid' do
      d1 = dog_klass.create
      d2 = dog_klass.create

      @o.dog_guids = [d1.guid, d2.guid]
      d1.refresh
      d2.refresh
      expect(@o.dogs).to include(d1)
      expect(@o.dogs).to include(d2)

      @o.dog_guids = [d2.guid]
      d1.refresh
      d2.refresh
      expect(@o.dogs).not_to include(d1)
      expect(@o.dogs).to include(d2)
    end

    it 'defines a <relation>_ids accessor method' do
      expect(@o.dog_ids).to be_empty
      expect(@o.dog_ids.respond_to?(:each)).to be(true)

      d1 = dog_klass.create
      d2 = dog_klass.create

      @o.add_dog d1
      expect(@o.dog_ids).to include(d1.id)

      @o.add_dog d2
      expect(@o.dog_ids).to include(d1.id)
      expect(@o.dog_ids).to include(d2.id)
    end

    it 'allows multiple adds of the same id' do
      d1 = dog_klass.create
      @o.add_dog d1
      @o.add_dog d1

      expect(@o.dogs).to include(d1)
      expect(@o.dogs.length).to eq(1)
    end

    it 'defines a remove_<relation> method that takes an object' do
      d1 = dog_klass.create
      d2 = dog_klass.create

      @o.add_dog d1
      @o.add_dog d2

      expect(@o.dogs).to include(d1)
      expect(@o.dogs).to include(d2)

      @o.remove_dog(d1)

      expect(@o.dogs).not_to include(d1)
      expect(@o.dogs).to include(d2)
      expect(@o.dogs.length).to eq(1)
    end

    it 'defines a remove_<relation> method that takes an id' do
      d1 = dog_klass.create
      d2 = dog_klass.create

      @o.add_dog d1
      @o.add_dog d2

      expect(@o.dogs).to include(d1)
      expect(@o.dogs).to include(d2)

      @o.remove_dog(d1.id)

      expect(@o.dogs).not_to include(d1)
      expect(@o.dogs).to include(d2)
      expect(@o.dogs.length).to eq(1)
    end

    it 'raises an error on add using the <relation>_guids=' do
      expect { @o.dog_guids = ['bogus-guid'] }.to raise_error(CloudController::Errors::ApiError, /Could not find/)
    end

    it 'raises an error using the remove_<relation>_by_guid' do
      expect { @o.remove_dog_by_guid('bogus-guid') }.to raise_error(CloudController::Errors::ApiError, /Could not find/)
    end
  end

  describe '.many_to_many' do
    before do
      @d1 = dog_klass.create
      @d2 = dog_klass.create

      @n1 = name_klass.create
      @n2 = name_klass.create

      expect { @d1.names }.to raise_error(NoMethodError)
      expect { @n1.names }.to raise_error(NoMethodError)

      dog_klass.many_to_many :names
      name_klass.many_to_many :dogs

      expect(@d1.names).to be_empty
      expect(@d2.names).to be_empty
      expect(@n1.dogs).to be_empty
      expect(@n2.dogs).to be_empty
    end

    it 'adds a <relation> method' do
      expect(@d1.names).to be_empty
    end

    it 'adds a add_<relation> method that takes an object' do
      @d1.add_name @n1
      expect(@d1.names).to include(@n1)
      expect(@n1.dogs).to include(@d1)
    end

    it 'adds a add_<relation> method that takes an id' do
      @d1.add_name @n1.id
      expect(@d1.names).to include(@n1)
      @n1.refresh
      expect(@n1.dogs).to include(@d1)
    end

    it 'adds a <relation>_ids= method that takes an array of ids' do
      @d1.name_ids = [@n1.id, @n2.id]
      @n1.refresh
      @n2.refresh
      expect(@d1.names).to include(@n1)
      expect(@d1.names).to include(@n2)
      expect(@n1.dogs).to include(@d1)
      expect(@n2.dogs).to include(@d1)

      @d1.name_ids = [@n2.id]
      @n1.refresh
      @n2.refresh
      expect(@d1.names).not_to include(@n1)
      expect(@d1.names).to include(@n2)

      expect(@n1.dogs).to be_empty
      expect(@n2.dogs).to include(@d1)
    end

    it 'adds a add_<relation> method that takes a guid' do
      @d1.add_name_by_guid @n1.guid
      expect(@d1.names).to include(@n1)
      @n1.refresh
      expect(@n1.dogs).to include(@d1)
    end

    it 'adds a <relation>_guids= method that takes an array of guids' do
      @d1.name_guids = [@n1.guid, @n2.guid]
      @n1.refresh
      @n2.refresh
      expect(@d1.names).to include(@n1)
      expect(@d1.names).to include(@n2)
      expect(@n1.dogs).to include(@d1)
      expect(@n2.dogs).to include(@d1)

      @d1.name_guids = [@n2.guid]
      @n1.refresh
      @n2.refresh
      expect(@d1.names).not_to include(@n1)
      expect(@d1.names).to include(@n2)

      expect(@n1.dogs).to be_empty
      expect(@n2.dogs).to include(@d1)
    end

    it 'defines a <relation>_ids accessor method' do
      expect(@d1.name_ids).to be_empty
      expect(@d1.name_ids.respond_to?(:each)).to be(true)

      @d1.name_ids = [@n1.id, @n2.id]
      expect(@d1.name_ids).to include(@n1.id)
      expect(@d1.name_ids).to include(@n2.id)

      @d1.name_ids = [@n2.id]
      expect(@d1.name_ids).not_to include(@n1.id)
      expect(@d1.name_ids).to include(@n2.id)
    end

    it 'allows multiple adds of the same object' do
      @d1.add_name @n1
      @d1.add_name @n1
      expect(@d1.names).to include(@n1)
      expect(@d1.names.length).to eq(1)
    end

    it 'allows multiple adds of the same id' do
      @d1.add_name @n1.id
      @d1.add_name @n1.id
      @n1.refresh
      expect(@d1.names).to include(@n1)
      expect(@d1.names.length).to eq(1)
    end

    it 'defines a remove_<relation> method that takes an object' do
      @d1.add_name @n1
      @d1.add_name @n2

      expect(@d1.names).to include(@n1)
      expect(@d1.names).to include(@n2)

      @d1.remove_name(@n1)

      expect(@d1.names).not_to include(@n1)
      expect(@d1.names).to include(@n2)
      expect(@d1.names.length).to eq(1)

      expect(@n1.dogs).to be_empty
      expect(@n2.dogs).to include(@d1)
      expect(@d1.names.length).to eq(1)
    end

    it 'defines a remove_<relation> method that takes an id' do
      @d1.add_name @n1
      @d1.add_name @n2

      expect(@d1.names).to include(@n1)
      expect(@d1.names).to include(@n2)

      @d1.remove_name(@n1.id)
      @n1.refresh

      expect(@d1.names).not_to include(@n1)
      expect(@d1.names).to include(@n2)
      expect(@d1.names.length).to eq(1)

      expect(@n1.dogs).to be_empty
      expect(@n2.dogs).to include(@d1)
      expect(@d1.names.length).to eq(1)
    end

    it 'raises an error on add using the <relation>_guids=' do
      expect { @d1.name_guids = ['bogus-guid'] }.to raise_error(CloudController::Errors::ApiError, /Could not find/)
    end

    it 'raises an error using the remove_<relation>_by_guid' do
      expect { @d1.remove_name_by_guid('bogus-guid') }.to raise_error(CloudController::Errors::ApiError, /Could not find/)
    end

    context 'concurrent insert statements' do
      let(:db_connection) { DbConfig.new.connection }

      before do
        allow(@d1).to receive(:add_associated_object).and_wrap_original do |original_add_associated_object, *args, &block|
          # rubocop:disable Rails/SkipsModelValidations
          db_connection[:dogs_names].insert(dog_id: @d1.id, name_id: @n1.id) # Simulate concurrent insert from a different thread/connection
          # rubocop:enable Rails/SkipsModelValidations
          expect(db_connection[:dogs_names].count).to eq(1)
          original_add_associated_object.call(*args, &block) # this will raise the UniqueConstraintViolation error
        end
      end

      it 'raises an UniqueConstraintViolation error' do
        expect { @d1.add_name(@n1) }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'does not catch other errors accidentally' do
        allow(@d1).to receive(:add_associated_object).and_raise(Sequel::DatabaseError.new('some other error'))
        expect { @d1.add_name(@n1) }.to raise_error(Sequel::DatabaseError, /some other error/)
      end

      context 'with ignored_unique_constraint_violation_errors option' do
        before { dog_klass.many_to_many :names, ignored_unique_constraint_violation_errors: %w[dog_id_name_id_idx] }

        it('catches the error and makes the insert idempotent when called with an object') do
          expect { @d1.add_name(@n1) }.not_to raise_error
        end

        it 'catches the error and makes the insert idempotent when called with an id' do
          expect { @d1.add_name(@n1.id) }.not_to raise_error
        end

        it 'does not rollback or modify other entries in the join table' do
          db_connection[:dogs_names].db.transaction do
            expect { @d1.add_name(@n2) }.not_to raise_error
            expect(db_connection[:dogs_names].count).to eq(2)
            expect(@d1.names).to include(@n2)
          end
        end
      end

      context 'when the join table does not have a unique constraint' do
        # This test proves that without a unique constraint or combined primary key duplicate entries can be created
        # Join tables should always have a unique constraint or combined primary key
        before do
          skip unless db_connection.database_type == :postgres # mysql does not allow dropping foreign key connected indexes easily
          db_connection.run('DROP INDEX IF EXISTS dog_id_name_id_idx')
        end

        it 'creates duplicate entries' do
          expect { @d1.add_name(@n1) }.not_to raise_error
          expect(db_connection[:dogs_names].count).to eq(2)
        end
      end
    end
  end

  describe '#has_one_to_many?' do
    let!(:owner) { owner_klass.create }

    before { owner_klass.one_to_many :dogs }

    it 'returns true when there are one_to_many associations' do
      d = dog_klass.create
      owner.add_dog(d)
      expect(owner.has_one_to_many?(:dogs)).to be(true)
    end

    it 'returns false when there are NO one_to_many associations' do
      expect(owner.has_one_to_many?(:dogs)).to be(false)
    end
  end

  describe '#has_one_to_one?' do
    let!(:owner) { owner_klass.create }

    before { owner_klass.one_to_one :dog }

    it 'returns true when there are one_to_one associations' do
      d = dog_klass.create
      owner.dog = d
      expect(owner.has_one_to_one?(:dog)).to be(true)
    end

    it 'returns false when there are NO one_to_one associations' do
      expect(owner.has_one_to_one?(:dog)).to be(false)
    end
  end

  describe '#association_type' do
    let!(:owner) { owner_klass.create }

    it 'returns one_to_one association type when it is defined' do
      owner_klass.one_to_one :dog
      expect(owner.association_type(:dog)).to eq(:one_to_one)
    end

    it 'returns one_to_many association type when it is defined' do
      owner_klass.one_to_many :dog
      expect(owner.association_type(:dog)).to eq(:one_to_many)
    end
  end

  describe 'relationship_dataset' do
    before do
      bottom = bottom_klass

      top_klass.one_to_many :middles
      top_klass.one_to_many :bottoms, dataset: lambda {
        bottom.filter(middle: middles)
      }

      middle_klass.one_to_one :top
      middle_klass.one_to_many :bottoms

      bottom_klass.many_to_one :middle
    end

    let!(:bottoms) { Array.new(10) { bottom_klass.create } }

    let!(:middle) do
      middle_klass.create.tap do |m|
        m.bottom_ids = bottoms.collect(&:id)
        m.save
      end
    end

    let!(:top) do
      top_klass.create.tap do |t|
        t.middle_ids = [middle.id]
        t.save
      end
    end

    context 'with no custom dataset defined' do
      it 'uses the full dataset of the related model' do
        all = middle.relationship_dataset(:bottoms).all
        expect(all.size).to eq(10)
        expect(all).to eq(bottom_klass.all)
      end
    end

    context 'with a custom dataset for the relationship' do
      it 'uses the custom dataset' do
        all = top.relationship_dataset(:bottoms).all
        expect(all.size).to eq(10)
        expect(all).to eq(bottom_klass.all)
      end
    end
  end

  describe '.many_to_one' do
    before { initialize_relations }

    let!(:middle) { middle_klass.create(guid: 'middle-guid') }
    let!(:other_middle) { middle_klass.create(guid: 'other_middle_guid') }

    let!(:bottoms) { Array.new(1) { bottom_klass.create(middle:) } }

    context 'the default behaviour' do
      def initialize_relations
        bottom_klass.many_to_one :middle
      end

      it 'adds a middle_guid accessor to bottom' do
        bottom = bottoms.first
        expect(bottom.middle_guid).to eq('middle-guid')
        bottom.middle_guid = 'other_middle_guid'
        bottom.save
        expect(bottom.middle_guid).to eq('other_middle_guid')
      end
    end

    context 'with the :without_guid_generation flag' do
      def initialize_relations
        bottom_klass.many_to_one :middle, without_guid_generation: true
      end

      it 'does not add a middle_guid accessor to bottom' do
        bottom = bottoms.first

        expect do
          bottom.middle_guid
        end.to raise_error(NoMethodError)

        expect do
          bottom.middle_guid = 'hello'
        end.to raise_error(NoMethodError)
      end
    end

    context 'when an invalid guid is passed' do
      def initialize_relations
        bottom_klass.many_to_one :middle
      end

      it 'raises an error' do
        bottom = bottoms.first
        expect { bottom.middle_guid = 'bogus-guid' }.to raise_error(CloudController::Errors::ApiError, /Could not find Middle/)
      end
    end
  end
end
