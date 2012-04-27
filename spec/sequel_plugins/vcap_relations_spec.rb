# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe "Sequel::Plugins::VcapRelations" do
  before do
    db = Sequel.sqlite

    db.create_table :owners do
      primary_key :id
    end

    db.create_table :dogs do
      primary_key :id

      # a dog has an owner, (but allowing null, it may be a stray)
      foreign_key :owner_id, :owners
    end

    db.create_table :names do
      primary_key :id
    end

    # contrived example.. there is a many-to-many relationship between a dog
    # and a name, i.e. the main name plus all the nick names a dog can go by
    db.create_table :dogs_names do
      foreign_key :dog_id,  :dogs,  :null => false
      foreign_key :name_id, :names, :null => false

      # needed to expose the many_to_many add flaw in native Sequel
      index [:dog_id, :name_id], :unique => true
    end

    # we need new classes each time to reset the class level state
    def define_model(name, db)
      c = Class.new(Sequel::Model) do
        plugin :vcap_relations
      end
      self.class.send(:remove_const, name) if self.class.const_defined?(name)
      self.class.const_set(name, c)
      c.set_dataset(db["#{name.downcase.to_s}s".to_sym])
    end

    define_model :Owner, db
    define_model :Dog, db
    define_model :Name, db
  end

  describe "#one_to_many" do
    before do
      @o = Owner.create
      lambda { @o.dogs }.should raise_error(NoMethodError)
      Owner.one_to_many :dogs
    end

    it "should add a <relation> method" do
      @o.dogs.should be_empty
    end

    it "should add a add_<relation> method that takes an object" do
      d = Dog.create
      @o.add_dog d
      @o.dogs.should include(d)
    end

    it "should add a add_<relation> method that takes an id" do
      d = Dog.create
      @o.add_dog d.id
      d.refresh
      @o.dogs.should include(d)
    end

    it "should add a <relation>_ids= method that takes an array of ids" do
      d1 = Dog.create
      d2 = Dog.create

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

    it "should define a <relation>_ids accessor method" do
      @o.dog_ids.should be_empty
      @o.dog_ids.respond_to?(:each).should == true

      d1 = Dog.create
      d2 = Dog.create

      @o.add_dog d1
      @o.dog_ids.should include(d1.id)

      @o.add_dog d2
      @o.dog_ids.should include(d1.id)
      @o.dog_ids.should include(d2.id)
    end

    it "should allow multiple adds of the same id" do
      d1 = Dog.create
      @o.add_dog d1
      @o.add_dog d1

      @o.dogs.should include(d1)
      @o.dogs.length.should == 1
    end

    it "should define a remove_<relation> method that takes an object" do
      d1 = Dog.create
      d2 = Dog.create

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
      d1 = Dog.create
      d2 = Dog.create

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

  describe "#many_to_many" do
    before do
      @d1 = Dog.create
      @d2 = Dog.create

      @n1 = Name.create
      @n2 = Name.create

      lambda { @d1.names }.should raise_error(NoMethodError)
      lambda { @n1.names }.should raise_error(NoMethodError)

      Dog.many_to_many :names
      Name.many_to_many :dogs

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
end
