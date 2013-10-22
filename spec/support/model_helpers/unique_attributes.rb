module ModelHelpers
  shared_examples "creation of unique attributes" do |example_opts|
    if example_opts[:unique_attributes]
      example_opts[:unique_attributes].map{|keys| Array(keys)}.each do |unique_key|
        column_list = unique_key.flatten.map do |v|
          if described_class.associations.include?(v.to_sym)
            v = v.to_s.concat("_id")
          end
          v
        end

        factory = ->(attrs={}, opts={save: true}) do
          if example_opts[:custom_attributes_for_uniqueness_tests]
            actual_attrs = example_opts[:custom_attributes_for_uniqueness_tests].call.merge(attrs)
          else
            actual_attrs = attrs
          end

          if opts[:save]
            described_class.make(actual_attrs)
          else
            described_class.make_unsaved(actual_attrs)
          end
        end

        it_validates_the_uniqueness_of_attrs_in_model(*column_list, factory: factory)
        unless example_opts[:skip_database_constraints]
          it_validates_the_uniqueness_of_columns_in_database(*column_list, factory: factory)
        end
      end
    end
  end
end

def it_validates_the_uniqueness_of_attrs_in_model(*unique_keys)
  opts = unique_keys.last.is_a?(Hash) ? unique_keys.pop : {}
  factory = opts[:factory]

  context "creating a second instance with the same value for #{unique_keys.inspect}" do
    let!(:existing_instance) { factory.call }
    let(:duplicate_attrs_for_unique_fields) do
      unique_keys.each.with_object({}) do |unique_key, dup_attrs|
        dup_attrs[unique_key] = existing_instance.public_send(unique_key)
      end
    end

    def ensure_sequel_error_for_all_columns!(column_list, error)
      number_of_uniqueness_errors = error.message.scan(/\bunique\b/).count
      if number_of_uniqueness_errors == 0
        fail "There was no uniqueness error"
      elsif number_of_uniqueness_errors > 1
        fail "Received multiple uniqueness validation errors." +
             " You may be enforcing uniqueness on multiple columns individually instead of as a group." +
             " For example, you may think that [:name, :email] are unique as a pair, but instead" +
             " :name is globally unique and :email is globally unique"
      end
      columns_in_error = error.message[/^(.*) unique/, 1].split(" and ")
      columns_in_error.should =~ column_list.map(&:to_s)
    end

    it "should fail to validate" do
      expect {
        factory.call(duplicate_attrs_for_unique_fields)
      }.to raise_error(Sequel::ValidationFailed) { |error|
        ensure_sequel_error_for_all_columns!(unique_keys, error)
      }
    end
  end
end

def it_validates_the_uniqueness_of_columns_in_database(*unique_keys)
  opts = unique_keys.last.is_a?(Hash) ? unique_keys.pop : {}
  factory = opts[:factory]

  context "saving a second instance with the same values for #{unique_keys.inspect} to the database without validation" do
    let!(:existing_instance) { factory.call }
    let(:duplicate_attrs_for_unique_fields) do
      unique_keys.each.with_object({}) { |unique_key, dup_attrs|
        dup_attrs[unique_key] = existing_instance.public_send(unique_key)
      }
    end

    def ensure_uniqueness_required_for_columns!(column_list, error)
      case described_class.db.database_type
      when :mysql
        error.message.should == "Duplicate entry"
      when :sqlite
        columns_in_error = error.message[/columns? (.*?) (is|are) not unique/, 1]
        columns_in_error.split(', ').should =~ column_list
      end
    end

    it "fails due to database integrity checks" do
      expect {
        instance_with_duplicate_fields = factory.call(duplicate_attrs_for_unique_fields, save: false)
        instance_with_duplicate_fields.save(validate: false)
      }.to raise_error Sequel::DatabaseError do |error|
        ensure_uniqueness_required_for_columns!(unique_keys, error)
      end
    end
  end

  if unique_keys.length > 1
    # this proves that it is a multi-field unique key instead of multiple single-field unique keys
    unique_keys.each do |subkey|
      context "saving a second instance with the same values for only #{subkey.inspect} to the database without validation" do
        let!(:existing_instance) { factory.call }

        it "saves successfully" do
          expect {
            unsaved_instance = factory.call
            unsaved_instance.send(:"#{subkey}=", existing_instance.public_send(subkey))
            unsaved_instance.save(:validate => false)
          }.not_to raise_error
        end
      end
    end
  end
end
