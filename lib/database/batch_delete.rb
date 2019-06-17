module Database
  class BatchDelete
    attr_reader :amount, :dataset

    def initialize(dataset, amount=1000)
      @dataset = dataset
      @amount = amount
    end

    def delete
      loop do
        set = dataset.limit(amount)
        break if set.count == 0

        delete_batch(set)
      end
    end

    private

    def delete_batch(set)
      dataset.model.where(id: set.select_map(:id)).delete
    end
  end
end
