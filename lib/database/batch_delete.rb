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
        # Fetch the batch's ids in the same query that checks for emptiness, so the
        # (potentially expensive) filtered dataset is evaluated once per batch.
        ids = dataset.limit(amount).select_map(:id)
        break if ids.empty?

        total_count += delete_batch(ids)
      end

      total_count
    end

    private

    def delete_batch(ids)
      dataset.model.where(id: ids).delete
    end
  end
end
