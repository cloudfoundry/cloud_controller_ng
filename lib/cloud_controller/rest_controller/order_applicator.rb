module VCAP::CloudController::RestController
  class OrderApplicator
    def initialize(opts)
      @order_by = Array(opts[:order_by] || :id).map(&:to_sym) # symbols
      @order_direction = opts[:order_direction] || 'asc'
    end

    def apply(dataset)
      validate!

      if descending?
        @order_by.inject(dataset) { |ds, col|
          sql = ds.sql.downcase
          # if the dataset is already ordered by a `col`, you should not order it by that `col` again.
          if sql =~ /order by .*#{col.downcase}.* asc$/ || sql =~ /order by .*#{col.downcase}.* desc$/
            ds.order_by(Sequel.desc(col))
          else
            ds.order_more(Sequel.desc(col))
          end
        }
      else
        @order_by.inject(dataset) { |ds, col|
          sql = ds.sql.downcase
          if sql =~ /order by .*#{col.downcase}.* asc$/ || sql =~ /order by .*#{col.downcase}.* desc$/
            ds.order_by(Sequel.asc(col))
          else
            ds.order_more(Sequel.asc(col))
          end
        }
      end
    end

    private

    def validate!
      unless %w(asc desc).include?(@order_direction)
        raise CloudController::Errors::ApiError.new_from_details(
          'BadQueryParameter',
          "order_direction must be 'asc' or 'desc' but was '#{@order_direction}'")
      end
    end

    def descending?
      @order_direction.downcase == 'desc'
    end
  end
end
