require "spec_helper"

describe "Sequel::Plugins::VcapRelations" do
  before do
    db.create_table :owners do
      primary_key :id
      String :guid, :null => false, :index => true
    end

    db.create_table :dogs do
      primary_key :id
      String :guid, :null => false, :index => true

      # a dog has an owner, (but allowing null, it may be a stray)
      foreign_key :owner_id, :owners
    end

    db.create_table :names do
      primary_key :id
      String :guid, :null => false, :index => true
    end

    # contrived example.. there is a many-to-many relationship between a dog
    # and a name, i.e. the main name plus all the nick names a dog can go by
    db.create_table :dogs_names do
      foreign_key :dog_id,  :dogs,  :null => false
      foreign_key :name_id, :names, :null => false

      # needed to expose the many_to_many add flaw in native Sequel
      index [:dog_id, :name_id], :unique => true
    end

    db.create_table :tops do
      primary_key :id
    end

    db.create_table :middles do
      primary_key :id
      String :guid, :null => false, :index => true
      foreign_key :top_id, :tops
    end

    db.create_table :bottoms do
      primary_key :id
      foreign_key :middle_id, :middles
    end

    # we need new classes each time to reset the class level state
    def define_model(name, db)
      c = Class.new(Sequel::Model) do
        plugin :vcap_relations
        plugin :vcap_guid
      end
      self.class.send(:remove_const, name) if self.class.const_defined?(name)
      self.class.const_set(name, c)
      c.set_dataset(db["#{name.downcase.to_s}s".to_sym])
    end

    define_model :Owner, db
    define_model :Dog, db
    define_model :Name, db

    define_model :Top, db
    define_model :Middle, db
    define_model :Bottom, db
  end

  after do
    [:dogs_names, :dogs, :names, :owners, :bottoms, :middles, :tops].each do |table_name|
      db.drop_table table_name
    end
  end

  let(:owner_klass) { self.class.const_get(:Owner) }
  let(:dog_klass) { self.class.const_get(:Dog) }
  let(:name_klass) { self.class.const_get(:Name) }
  let(:top_klass) { self.class.const_get(:Top) }
  let(:middle_klass) { self.class.const_get(:Middle) }
  let(:bottom_klass) { self.class.const_get(:Bottom) }

  describe ".one_to_many" do
    before do
      @o = owner_klass.create
      expect { @o.dogs }.to raise_error(NoMethodError)
      owner_klass.one_to_many :dogs
    end

    it "should add a <relation> method" do
      @o.dogs.should be_empty
    end

    it "should add a add_<relation> method that takes an object" do
      d = dog_klass.create
      @o.add_dog d
      @o.dogs.should include(d)
    end

    it "should add a add_<relation> method that takes an id" do
      d = dog_klass.create
      @o.add_dog d.id
      d.refresh
      @o.dogs.should include(d)
    end

    it "should add a <relation>_ids= method that takes an array of ids" do
      d1 = dog_klass.create
      d2 = dog_klass.create

      @o.dog_ids = [d1.id, d2.id]
      d1.refresh
      d2.refresh
      @o.dogs.should include(d1)
      @o.dogs.should include(d2)

      @o.dog_ids = [d2.id]
      d1.refresh
      d2.refresh
      @o.dogs.should_not include(d1)
      @o.dogs.should include(d2)
    end

    it "should add a add_<relation>_guids= method that takes a guid" do
      d1 = dog_klass.create
      d2 = dog_klass.create

      @o.dog_guids = [d1.guid, d2.guid]
      d1.refresh
      d2.refresh
      @o.dogs.should include(d1)
      @o.dogs.should include(d2)

      @o.dog_guids = [d2.guid]
      d1.refresh
      d2.refresh
      @o.dogs.should_not include(d1)
      @o.dogs.should include(d2)
    end

    it "should define a <relation>_ids accessor method" do
      @o.dog_ids.should be_empty
      @o.dog_ids.respond_to?(:each).should == true

      d1 = dog_klass.create
      d2 = dog_klass.create

      @o.add_dog d1
      @o.dog_ids.should include(d1.id)

      @o.add_dog d2
      @o.dog_ids.should include(d1.id)
      @o.dog_ids.should include(d2.id)
    end

    it "should allow multiple adds of the same id" do
      d1 = dog_klass.create
      @o.add_dog d1
      @o.add_dog d1

      @o.dogs.should include(d1)
      @o.dogs.length.should == 1
    end

    it "should define a remove_<relation> method that takes an object" do
      d1 = dog_klass.create
      d2 = dog_klass.create

      @o.add_dog d1
      @o.add_dog d2

      @o.dogs.should include(d1)
      @o.dogs.should include(d2)

      @o.remove_dog(d1)

      @o.dogs.should_not include(d1)
      @o.dogs.should include(d2)
      @o.dogs.length.should == 1
    end

    it "should define a remove_<relation> method that takes an id" do
      d1 = dog_klass.create
      d2 = dog_klass.create

      @o.add_dog d1
      @o.add_dog d2

      @o.dogs.should include(d1)
      @o.dogs.should include(d2)

      @o.remove_dog(d1.id)

      @o.dogs.should_not include(d1)
      @o.dogs.should include(d2)
      @o.dogs.length.should == 1
    end
  end

  describe ".many_to_many" do
    before do
      @d1 = dog_klass.create
      @d2 = dog_klass.create

      @n1 = name_klass.create
      @n2 = name_klass.create

      expect { @d1.names }.to raise_error(NoMethodError)
      expect { @n1.names }.to raise_error(NoMethodError)

      dog_klass.many_to_many :names
      name_klass.many_to_many :dogs

      @d1.names.should be_empty
      @d2.names.should be_empty
      @n1.dogs.should be_empty
      @n2.dogs.should be_empty
    end

    it "should add a <relation> method" do
      @d1.names.should be_empty
    end

    it "should add a add_<relation> method that takes an object" do
      @d1.add_name @n1
      @d1.names.should include(@n1)
      @n1.dogs.should include(@d1)
    end

    it "should add a add_<relation> method that takes an id" do
      @d1.add_name @n1.id
      @d1.names.should include(@n1)
      @n1.refresh
      @n1.dogs.should include(@d1)
    end

    it "should add a <relation>_ids= method that takes an array of ids" do
      @d1.name_ids = [@n1.id, @n2.id]
      @n1.refresh
      @n2.refresh
      @d1.names.should include(@n1)
      @d1.names.should include(@n2)
      @n1.dogs.should include(@d1)
      @n2.dogs.should include(@d1)

      @d1.name_ids = [@n2.id]
      @n1.refresh
      @n2.refresh
      @d1.names.should_not include(@n1)
      @d1.names.should include(@n2)

      @n1.dogs.should be_empty
      @n2.dogs.should include(@d1)
    end

    it "should add a add_<relation> method that takes a guid" do
      @d1.add_name_by_guid @n1.guid
      @d1.names.should include(@n1)
      @n1.refresh
      @n1.dogs.should include(@d1)
    end

    it "should add a <relation>_guids= method that takes an array of guids" do
      @d1.name_guids = [@n1.guid, @n2.guid]
      @n1.refresh
      @n2.refresh
      @d1.names.should include(@n1)
      @d1.names.should include(@n2)
      @n1.dogs.should include(@d1)
      @n2.dogs.should include(@d1)

      @d1.name_guids = [@n2.guid]
      @n1.refresh
      @n2.refresh
      @d1.names.should_not include(@n1)
      @d1.names.should include(@n2)

      @n1.dogs.should be_empty
      @n2.dogs.should include(@d1)
    end

    it "should define a <relation>_ids accessor method" do
      @d1.name_ids.should be_empty
      @d1.name_ids.respond_to?(:each).should == true

      @d1.name_ids = [@n1.id, @n2.id]
      @d1.name_ids.should include(@n1.id)
      @d1.name_ids.should include(@n2.id)

      @d1.name_ids = [@n2.id]
      @d1.name_ids.should_not include(@n1.id)
      @d1.name_ids.should include(@n2.id)
    end

    it "should allow multiple adds of the same object" do
      @d1.add_name @n1
      @d1.add_name @n1
      @d1.names.should include(@n1)
      @d1.names.length.should == 1
    end

    it "should allow multiple adds of the same id" do
      @d1.add_name @n1.id
      @d1.add_name @n1.id
      @n1.refresh
      @d1.names.should include(@n1)
      @d1.names.length.should == 1
    end

    it "should define a remove_<relation> method that takes an object" do
      @d1.add_name @n1
      @d1.add_name @n2

      @d1.names.should include(@n1)
      @d1.names.should include(@n2)

      @d1.remove_name(@n1)

      @d1.names.should_not include(@n1)
      @d1.names.should include(@n2)
      @d1.names.length.should == 1

      @n1.dogs.should be_empty
      @n2.dogs.should include(@d1)
      @d1.names.length.should == 1
    end

    it "should define a remove_<relation> method that takes an id" do
      @d1.add_name @n1
      @d1.add_name @n2

      @d1.names.should include(@n1)
      @d1.names.should include(@n2)

      @d1.remove_name(@n1.id)
      @n1.refresh

      @d1.names.should_not include(@n1)
      @d1.names.should include(@n2)
      @d1.names.length.should == 1

      @n1.dogs.should be_empty
      @n2.dogs.should include(@d1)
      @d1.names.length.should == 1
    end
  end

  describe "#has_one_to_many?" do
    let!(:owner) { owner_klass.create }
    before { owner_klass.one_to_many :dogs }

    it "should return true when there are one_to_many associations" do
      d = dog_klass.create
      owner.add_dog(d)
      owner.has_one_to_many?(:dogs).should == true
    end

    it "should return false when there are NO one_to_many associations" do
      owner.has_one_to_many?(:dogs).should == false
    end
  end

  describe "#has_one_to_one?" do
    let!(:owner) { owner_klass.create }
    before { owner_klass.one_to_one :dog }

    it "should return true when there are one_to_one associations" do
      d = dog_klass.create
      owner.dog = d
      owner.has_one_to_one?(:dog).should == true
    end

    it "should return false when there are NO one_to_one associations" do
      owner.has_one_to_one?(:dog).should == false
    end
  end

  describe "#association_type" do
    let!(:owner) { owner_klass.create }

    it "should return one_to_one association type when it is defined" do
      owner_klass.one_to_one :dog
      owner.association_type(:dog).should == :one_to_one
    end

    it "should return one_to_many association type when it is defined" do
      owner_klass.one_to_many :dog
      owner.association_type(:dog).should == :one_to_many
    end
  end

  describe "relationship_dataset" do
    before do
      bottom = bottom_klass

      top_klass.one_to_many :middles
      top_klass.one_to_many :bottoms, :dataset => lambda {
        bottom.filter(:middle => middles)
      }

      middle_klass.one_to_one :top
      middle_klass.one_to_many :bottoms

      bottom_klass.many_to_one :middle
    end

    let!(:bottoms) do
      10.times.collect do
        bottom_klass.create
      end
    end

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

    context "with no custom dataset defined" do
      it "uses the full dataset of the related model" do
        all = middle.relationship_dataset(:bottoms).all
        all.size.should == 10
        all.should == bottom_klass.all
      end
    end

    context "with a custom dataset for the relationship" do
      it "uses the custom dataset" do
        all = top.relationship_dataset(:bottoms).all
        all.size.should == 10
        all.should == bottom_klass.all
      end
    end
  end

  describe ".many_to_one" do
    before { initialize_relations }

    let!(:middle) { middle_klass.create(:guid => "middle-guid") }
    let!(:other_middle) { middle_klass.create(:guid => "other_middle_guid") }

    let!(:bottoms) do
      10.times.collect do
        bottom_klass.create(:middle => middle)
      end
    end

    context "the default behaviour" do
      def initialize_relations
        bottom_klass.many_to_one :middle
      end

      it "adds a middle_guid accessor to bottom" do
        bottom = bottoms.first
        bottom.middle_guid.should == "middle-guid"
        bottom.middle_guid = "other_middle_guid"
        bottom.save
        bottom.middle_guid.should == "other_middle_guid"
      end
    end

    context "with the :without_guid_generation flag" do
      def initialize_relations
        bottom_klass.many_to_one :middle, :without_guid_generation => true
      end

      it "does not add a middle_guid accessor to bottom" do
        bottom = bottoms.first

        expect {
          bottom.middle_guid
        }.to raise_error(NoMethodError)

        expect {
          bottom.middle_guid = "hello"
        }.to raise_error(NoMethodError)
      end
    end
  end
end
