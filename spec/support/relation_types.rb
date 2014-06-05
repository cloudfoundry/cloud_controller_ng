module RelationTypes
  def self.all
    relations = []
    %w[one many].each do |cardinality_left|
      %w[zero_or_more zero_or_one one one_or_more].each do |cardinality_right|
        relations << "#{cardinality_left}_to_#{cardinality_right}".to_sym
      end
    end
    relations
  end
end
