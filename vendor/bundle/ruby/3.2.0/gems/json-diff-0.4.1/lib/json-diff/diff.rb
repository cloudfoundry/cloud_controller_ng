module JsonDiff

  def self.diff(before, after, opts = {})
    path = opts[:path] || ''
    include_addition = (opts[:additions] == nil) ? true : opts[:additions]
    include_moves = (opts[:moves] == nil) ? true : opts[:moves]
    include_was = (opts[:include_was] == nil) ? false : opts[:include_was]
    original_indices = (opts[:original_indices] == nil) ? false : opts[:original_indices]

    changes = []

    if before.is_a?(Hash)
      if !after.is_a?(Hash)
        changes << replace(path, include_was ? before : nil, after)
      else
        lost = before.keys - after.keys
        lost.each do |key|
          inner_path = extend_json_pointer(path, key)
          changes << remove(inner_path, include_was ? before[key] : nil)
        end

        if include_addition
          gained = after.keys - before.keys
          gained.each do |key|
            inner_path = extend_json_pointer(path, key)
            changes << add(inner_path, after[key])
          end
        end

        kept = before.keys & after.keys
        kept.each do |key|
          inner_path = extend_json_pointer(path, key)
          changes += diff(before[key], after[key], opts.merge(path: inner_path))
        end
      end
    elsif before.is_a?(Array)
      if !after.is_a?(Array)
        changes << replace(path, include_was ? before : nil, after)
      elsif before.size == 0
        if include_addition
          after.each_with_index do |item, index|
            inner_path = extend_json_pointer(path, index)
            changes << add(inner_path, item)
          end
        end
      elsif after.size == 0
        before.each do |item|
          # Delete elements from the start.
          inner_path = extend_json_pointer(path, 0)
          changes << remove(inner_path, include_was ? item : nil)
        end
      else
        pairing = array_pairing(before, after, opts)
        # FIXME: detect replacements.

        # All detected moves that do not reach the similarity limit are deleted
        # and re-added.
        pairing[:pairs].select! do |pair|
          sim = pair[2]
          kept = (sim >= 0.5)
          if !kept
            pairing[:removed] << pair[0]
            pairing[:added] << pair[1]
          end
          kept
        end

        pairing[:pairs].each do |pair|
          before_index, after_index = pair
          inner_path = extend_json_pointer(path, before_index)
          changes += diff(before[before_index], after[after_index], opts.merge(path: inner_path))
        end

        if !original_indices
          # Recompute indices to account for offsets from insertions and
          # deletions.
          pairing = array_changes(pairing)
        end

        pairing[:removed].each do |before_index|
          inner_path = extend_json_pointer(path, before_index)
          changes << remove(inner_path, include_was ? before[before_index] : nil)
        end

        pairing[:pairs].each do |pair|
          before_index, after_index = pair
          inner_before_path = extend_json_pointer(path, before_index)
          inner_after_path = extend_json_pointer(path, after_index)

          if before_index != after_index && include_moves
            changes << move(inner_before_path, inner_after_path)
          end
        end

        if include_addition
          pairing[:added].each do |after_index|
            inner_path = extend_json_pointer(path, after_index)
            changes << add(inner_path, after[after_index])
          end
        end
      end
    else
      if before != after
        changes << replace(path, include_was ? before : nil, after)
      end
    end

    changes
  end

  # {pairs: [[before index, after index, similarity]],
  #  removed: [before index],
  #  added: [after index]}
  #
  # - options[:similarity]: procedure taking (before, after) objects.
  #   Returns a probability between 0 and 1 of how likely `after` is a
  #   modification of `before`, or nil if it cannot determine it.
  def self.array_pairing(before, after, options)
    # Array containing the array of similarities from before to after.
    similarities = before.map do |before_item|
      after.map do |after_item|
        similarity(before_item, after_item, options)
      end
    end

    # Array containing the array of couples of indices, sorted by similarity.
    indices = before.map.with_index do |before_item, before_index|
      after.map.with_index do |after_item, after_index|
        [before_index, after_index]
      end
    end

    # Sort them in O(n^2 log(n)).
    indices.map! do |couples|
      couples.sort! do |a, b|
        a_before_index = a[0]
        b_before_index = b[0]
        a_after_index = a[1]
        b_after_index = b[1]

        similarities[b_before_index][b_after_index] <=> similarities[a_before_index][a_after_index]
      end
    end
    # Sort the toplevel.
    indices.sort! do |a, b|
      a_top_before_index = a[0][0]
      a_top_after_index = a[0][1]
      b_top_before_index = b[0][0]
      b_top_after_index = b[0][1]

      similarities[b_top_before_index][b_top_after_index] <=> similarities[a_top_before_index][a_top_after_index]
    end

    # Map from indices to boolean (true if paired).
    before_paired = {}
    after_paired = {}

    num_pairs = [before.size, after.size].min

    pairs = (0...num_pairs).map do |_|
      unpaired_before_index = indices.index { |a| !before_paired[a[0][0]] }
      unpaired_after_index = indices[unpaired_before_index].index { |a| !after_paired[a[1]] }
      unpaired_couple = indices[unpaired_before_index][unpaired_after_index]
      before_paired[unpaired_couple[0]] = true
      after_paired[unpaired_couple[1]] = true

      [unpaired_couple[0], unpaired_couple[1],
        similarities[unpaired_couple[0]][unpaired_couple[1]]]
    end

    if before.size < after.size
      added = after.map.with_index { |_, i| i} - after_paired.keys
      removed = []
    else
      removed = before.map.with_index { |_, i| i } - before_paired.keys
      added = []
    end

    {
      pairs: pairs,
      removed: removed,
      added: added,
    }
  end

  # Compute an arbitrary notion of how probable it is that one object is the
  # result of modifying the other.
  #
  # - options[:similarity]: procedure taking (before, after) objects.
  #   Returns a probability between 0 and 1 of how likely `after` is a
  #   modification of `before`, or nil if it cannot determine it.
  def self.similarity(before, after, options)
    return 0.0 if before.class != after.class

    # Use the custom similarity procedure if it isn't nil.
    if options[:similarity] != nil
      custom_result = options[:similarity].call(before, after)
      return custom_result if custom_result != nil
    end

    if before.is_a?(Hash)
      if before.size == 0
        if after.size == 0
          return 1.0
        else
          return 0.0
        end
      end

      # Average similarity between keys' value.
      # We don't consider key renames.
      similarities = []
      before.each do |before_key, before_item|
        similarities << similarity(before_item, after[before_key], options)
      end
      # Also consider keys' names.
      before_keys = before.keys
      after_keys = after.keys
      key_similarity = (before_keys & after_keys).size / (before_keys | after_keys).size
      similarities << key_similarity

      similarities.reduce(:+) / similarities.size
    elsif before.is_a?(Array)
      return 1.0 if before.size == 0

      # The most likely match between an element in the old and the new list is
      # presumably the right one, so we take the average of the maximum
      # similarity between each elements of the list.
      similarities = before.map do |before_item|
        after.map do |after_item|
          similarity(before_item, after_item, options)
        end.max || 0.0
      end

      similarities.reduce(:+) / similarities.size
    elsif before == after
      1.0
    else
      0.0
    end
  end

  # Input:
  # {pairs: [[before index, after index, similarity]],
  #  removed: [before index],
  #  added: [after index]}
  #
  # Output:
  # {removed: [before index],
  #  pairs: [[before index, after index,
  #    original before index, original after index]],
  #  added: [after index]}
  def self.array_changes(pairing)
    # We perform removals starting from the highest index.
    # That way, they don't offset their own.
    pairing[:removed].sort!.reverse!
    pairing[:added].sort!

    # First, map indices from before to after removals.
    removal_map = IndexMaps.new
    pairing[:removed].each { |rm| removal_map.removal(rm) }
    # And map indices from after to before additions
    # (removals, since it is reversed).
    addition_map = IndexMaps.new
    pairing[:added].reverse.each { |ad| addition_map.removal(ad) }

    moves = {}
    orig_before = {}
    orig_after = {}
    pairing[:pairs].each do |before, after|
      mapped_before = removal_map.map(before)
      mapped_after = addition_map.map(after)
      orig_before[mapped_before] = before
      orig_after[mapped_after] = after
      moves[mapped_before] = mapped_after
    end

    # Now, detect rings within the pairs.
    # The proof is, if whatever was at position i was sent to position j,
    # whatever was at position j cannot have stayed at j.
    # By induction, there is a ring.
    # Oh, and a piece of the proof is that the arrays have the same length.
    # Trivially. Right. Hey, this is not an interview!
    rings = []
    while moves.size > 0
      # i goes to j. j goes to (…). k goes to i.
      ring = []
      pair = moves.shift
      origin, target = pair
      first_origin = origin
      while target != first_origin
        ring << origin
        origin = target
        target = moves[target]
        moves.delete(origin)
      end
      ring << origin
      rings << ring
    end
    # rings is of the form [[i,j,k], …]

    # Finally, we can register the moves.
    # The idea is, if the whole ring moves instantaneously,
    # no element outside of the ring changed position.
    pairs = []
    rings.each do |ring|
      orig_ring = ring.map { |i| [orig_before[i], orig_after[i]] }
      ring_map = IndexMaps.new
      len = ring.size
      i = 0
      while i < len
        ni = (i + 1) % len  # next i
        if ring[i] != ring[ni]
          pairs << [ring_map.map(ring[i]), ring[ni], orig_ring[i][0], orig_ring[ni][1]]
        end
        ring_map.removal(ring[i])
        ring_map.addition(ring[ni])
        i += 1
      end
    end

    pairing[:pairs] = pairs

    pairing
  end

end
