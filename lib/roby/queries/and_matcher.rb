module Roby
    module Queries

    # This task combines multiple task matching predicates through a AND boolean
    # operator. I.e. it will match if none of the underlying predicates match.
    class AndMatcher < MatcherBase
        # Create a new AndMatcher object combining the given predicates.
	def initialize(*ops)
	    @ops = ops 
	end

        # Filters as much as non-matching tasks as possible out of +task_set+,
        # based on the information in +task_index+
	def filter(task_set, task_index)
	    result = task_set
	    for child in @ops
		result &= child.filter(task_set, task_index)
	    end
	    result
	end

        # Add a new predicate to the combination
	def <<(op); @ops << op end

        # True if the task matches at least one of the underlying predicates
	def ===(task)
	    @ops.all? { |op| op === task }
	end
    end

    end
end
