module JsonDiff

  class IndexMaps
    def initialize
      @maps = []
    end

    def addition(index)
      @maps << AdditionIndexMap.new(index)
    end

    def removal(index)
      @maps << RemovalIndexMap.new(index)
    end

    def map(index)
      @maps.each do |map|
        index = map.map(index)
      end
      index
    end
  end

  class IndexMap
    def initialize(pivot)
      @pivot = pivot
    end
  end

  class AdditionIndexMap < IndexMap
    def map(index)
      if index >= @pivot
        index + 1
      else
        index
      end
    end
  end

  class RemovalIndexMap < IndexMap
    def map(index)
      if index >= @pivot
        index - 1
      else
        index
      end
    end
  end

end
