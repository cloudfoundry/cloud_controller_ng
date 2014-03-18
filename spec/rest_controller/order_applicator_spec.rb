require "spec_helper"

module VCAP::CloudController::RestController
  describe OrderApplicator do
    subject(:order_applicator) do
      OrderApplicator.new(opts)
    end

    describe "#apply" do
      let(:db) do
        db = Sequel.sqlite(':memory:')
        db.create_table :examples do
          primary_key :id
          String :field
        end
        db
      end

      let(:dataset) do
        db[:examples]
      end

      subject(:sql) do
        order_applicator.apply(dataset).sql
      end

      context "when order_by is unspecified" do
        let(:opts) do
          {}
        end

        it "orders by id" do
          expect(sql).to eq("SELECT * FROM `examples` ORDER BY `id`")
        end
      end

      context "when order_by is specified" do
        let(:opts) do
          {order_by: "field"}
        end

        it "orders by the specified column" do
          expect(sql).to eq("SELECT * FROM `examples` ORDER BY `field`")
        end
      end
    end
  end
end
