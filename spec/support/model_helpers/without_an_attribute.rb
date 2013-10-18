module ModelHelpers
  shared_examples "creation without an attribute" do |opts|
    opts[:required_attributes].each do |without_attr|
      context "without the :#{without_attr.to_s} attribute" do
        let(:filtered_opts) do
          creation_opts.select do |k, v|
            k != without_attr and k != "#{without_attr}_id".to_sym
          end
        end

        it "should fail due to Sequel validations" do
          expect {
            described_class.create do |instance|
              instance.set_all(filtered_opts)
            end
          }.to raise_error Sequel::ValidationFailed, /#{without_attr}/
        end

        if !opts[:db_required_attributes]
          it "should fail due to database integrity checks" do
            expect {
              described_class.new do |instance|
                instance.set_all(filtered_opts)
              end.save(:validate => false)
            }.to raise_error Sequel::DatabaseError, /#{without_attr}/
          end
        end
      end
    end

    opts.fetch(:db_required_attributes, []).each do |db_required_attr|
      it "does not allow null value in the database for #{db_required_attr}" do
        Hash[described_class.db.schema(described_class.table_name)]
        .fetch(db_required_attr)
        .fetch(:allow_null).should == false
      end
    end
  end
end
