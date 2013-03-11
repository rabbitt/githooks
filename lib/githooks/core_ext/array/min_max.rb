require 'githooks/core_ext/numbers/infinity'

class Array
  def min(&block)
    collection = block_given? ? collect { |obj| yield obj } : self
    collection.inject(Infinity) { |min, num|
      min = num < min ? num : min; min
    }
  end

  def max(&block)
    collection = block_given? ? collect { |obj| yield obj } : self
    collection.inject(0) { |max, num|
      max = num > max ? num : max; max
    }
  end
end
