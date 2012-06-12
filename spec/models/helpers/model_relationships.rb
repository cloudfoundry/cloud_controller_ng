# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  relation_types = VCAP::CloudController::ModelSpecHelper.relation_types

  shared_examples "model relationships" do |opts|
    # make array of [assocation, create_for, relation_type]
    relations = []
    relation_types.each do |relation_type|
      relations += opts[relation_type].map { |e| e << relation_type }
    end

    relations.each do |association, create_for, relation_type|
      describe "#{association}" do
        let(:obj) { described_class.make }

        cardinality_self, cardinality_other = relation_type.to_s.split("_to_").map { |e| e.to_sym }
        singular_association = association.to_s.singularize
        if cardinality_other =~ /or_more/
          let(:add_attribute) { "add_#{singular_association}" }
        else
          let(:add_attribute) { "#{association}=" }
        end

        case cardinality_other
        when :one
          it "should have one #{association} when first created" do
            obj.send(association).should_not be_nil
          end
        when :zero_or_more
          it "should have no #{association} when first created" do
            obj.send(association).should be_empty
          end
        end

        it "should get associated with a #{association}" do
          related = create_for.call(obj)
          obj.send(add_attribute, related)
          obj.save

          if cardinality_other =~ /or_more/
            obj.send(association).should include(related)
          else
            obj.send(association).should == related
          end
        end

        if cardinality_other =~ /or_more/
          it "should get associated with many #{association}" do
            2.times do
              related = create_for.call(obj)
              obj.send(add_attribute, related)
              obj.save
            end
            obj.send(association).length.should == 2
          end
        end

        it "should get associated with a #{singular_association} only once" do
          related = create_for.call(obj)
          2.times do
            obj.send(add_attribute, related)
            obj.save
          end

          if cardinality_other =~ /or_more/
            obj.send(association).length.should == 1
          end
        end

        if (described_class != VCAP::CloudController::Models::User &&
            (cardinality_other =~ /one/ && (cardinality_self == :many || cardinality_other =~ /or_more/)))
          it "should fail to destroy #{singular_association} due to database integrity checks" do
            related = create_for.call(obj)
            obj.send(add_attribute, related)
            obj.save
            lambda {
              related.destroy
            }.should raise_error Sequel::DatabaseError, /foreign key/
          end
        else
          it "should destroy #{singular_association} successfully" do
            related = create_for.call(obj)
            obj.send(add_attribute, related)
            obj.save
            related.destroy
          end
        end
      end
    end
  end
end
