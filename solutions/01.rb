class Array

  def to_hash
    inject({}) do |hash, element| 
      hash[element.first] = element.last
      hash
    end
  end
  
  def index_by
    map { |element| [yield(element), element] }.to_hash
  end
  
  def subarray_count(subarray)
    each_cons(subarray.length).count(subarray)
  end
  
  def occurences_count
    Hash.new { |hash, key| 0 }.tap do |result|
      each { |element| result[element] += 1 }
    end
  end
end
