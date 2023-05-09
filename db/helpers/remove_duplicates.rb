# Remove duplicate entries based on 3 column values (leaving the one with the highest id)

def remove_duplicates(db, table, column_1, column_2, column_3)
  dup_groups = db[table].exclude(column_1.nil?).
               select(column_1, column_2, column_3).
               group_by(column_1, column_2, column_3).
               having { count.function.* > 1 }

  dup_groups.each do |group|
    c1 = group[column_1]
    c2 = group[column_2]
    c3 = group[column_3]

    if c2.nil? && c3.nil?
      ids_to_remove = db[table].
                      where(Sequel.lit("#{table}.#{column_1} = '#{c1}' and #{table}.#{column_2} IS NULL and #{table}.#{column_3} IS NULL ")).
                      order(Sequel.desc(:id)).
                      offset(1).
                      select_map(:id)
    elsif c3.nil?
      ids_to_remove = db[table].
                      where(Sequel.lit("#{table}.#{column_1} = '#{c1}' and #{table}.#{column_2} = '#{c2}' and #{table}.#{column_3} IS NULL")).
                      order(Sequel.desc(:id)).
                      offset(1).
                      select_map(:id)
    elsif c2.nil?
      ids_to_remove = db[table].
                      where(Sequel.lit("#{table}.#{column_1} = '#{c1}' and #{table}.#{column_2} IS NULL and #{table}.#{column_3} = '#{c3}'")).
                      order(Sequel.desc(:id)).
                      offset(1).
                      select_map(:id)
    else
      ids_to_remove = db[table].
                      where(Sequel.lit("#{table}.#{column_1} = '#{c1}' and #{table}.#{column_2} = '#{c2}' and #{table}.#{column_3} = '#{c3}'")).
                      order(Sequel.desc(:id)).
                      offset(1).
                      select_map(:id)
    end

    db[table].where(id: ids_to_remove).delete
  end
end
