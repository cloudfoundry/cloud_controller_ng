require "spec_helper"

module VCAP::CloudController::RestController
  describe OrderApplicator do
    subject(:order_applicator) do
      OrderApplicator.new(opts)
    end

    def normalize_quotes(string)
      return string unless dataset.db.database_type == :postgres
      string.gsub '`', '"'
    end

    describe "#apply" do
      let(:dataset) do
        VCAP::CloudController::TestModel.db[:test_models]
      end

      subject(:sql) do
        order_applicator.apply(dataset).sql
      end

      context "when order_by and order_direction are unspecified" do
        let(:opts) do
          {}
        end

        it "orders by id in ascending order" do
          expect(sql).to eq(normalize_quotes "SELECT * FROM `test_models` ORDER BY `id` ASC")
        end
      end

      context "when order_by is specified" do
        let(:opts) do
          {order_by: "field"}
        end

        it "orders by the specified column" do
          expect(sql).to eq(normalize_quotes "SELECT * FROM `test_models` ORDER BY `field` ASC")
        end
      end

      context "when order_direction is specified" do
        let(:opts) do
          {order_direction: "desc"}
        end

        it "orders by id in the specified direction" do
          expect(sql).to eq(normalize_quotes "SELECT * FROM `test_models` ORDER BY `id` DESC")
        end
      end

      context "when order_direction is specified with an invalid value" do
        let(:opts) do
          {order_direction: "decs"}
        end

        it "raises an error which makes sense to an api client" do
          expect { sql }.to raise_error(VCAP::Errors::ApiError)
        end
      end
    end
  end
end
