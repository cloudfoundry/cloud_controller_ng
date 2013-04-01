# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../cloud_controller_model", __FILE__)

module VCAP::CloudController::ModelSpecHelper
  relation_types = VCAP::CloudController::ModelSpecHelper.relation_types

  shared_examples "model relationships" do |opts|
    # make array of [assocation, test_opts, relation_type]
    relations = []
    relation_types.each do |relation_type|
      relations += opts[relation_type].map { |e| e << relation_type }
    end

    relations.each do |association, test_opts, relation_type|
      create_for = nil
      delete_ok = false

      if test_opts.kind_of?(Hash)
        create_for = test_opts[:create_for]
        delete_ok = test_opts[:delete_ok]
      else
        create_for = test_opts
      end

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
          # Reload the record to reconcile potential difference in time
          # resolution between the Ruby interpreter and the underlying
          # Database.
          related.reload

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

        if (!delete_ok &&
            (described_class != VCAP::CloudController::Models::User) &&
            (cardinality_other =~ /one/ && (cardinality_self == :many || cardinality_other =~ /or_more/)))
          it "should fail to destroy #{singular_association} due to database integrity checks" do
            related = create_for.call(obj)
            obj.send(add_attribute, related)
            obj.save

            error_class = "#{singular_association.capitalize}NotEmpty"
            error_type = if VCAP::Errors.const_defined?(error_class)
              [VCAP::Errors.const_get(error_class)]
            else
              # TODO: delete when Orgs, Apps, etc have a NotEmpty error
              [Sequel::DatabaseError, /foreign key/]
            end

            expect {
              related.destroy
            }.to raise_error *error_type
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
