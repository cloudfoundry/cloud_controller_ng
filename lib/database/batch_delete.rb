module Database
  class BatchDelete
    attr_reader :amount, :dataset

    def initialize(dataset, amount=1000)
      @dataset = dataset
      @amount = amount
    end

    def delete
      total_count = 0

      loop do
        set = dataset.limit(amount)
        set_count = set.count
        break if set_count == 0

        total_count += set_count
        delete_batch(set)
      end

      total_count
    end

    private

    def delete_batch(set)
      dataset.model.where(id: set.select_map(:id)).delete
    end
  end
end
