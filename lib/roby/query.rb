module Roby
    class Task
        # Returns a TaskMatcher object
	def self.match
	    TaskMatcher.new
	end
    end

    # This class represents a predicate which can be used to filter tasks. To
    # filter plan-related properties, use Query.
    #
    # A TaskMatcher object is a AND combination of various tests against tasks.
    class TaskMatcher
	attr_reader :model, :arguments
	attr_reader :predicates, :neg_predicates, :owners

	attr_reader :improved_information
	attr_reader :needed_information

        # Initializes an empty TaskMatcher object
	def initialize
	    @predicates           = ValueSet.new
	    @neg_predicates       = ValueSet.new
	    @owners               = Array.new
	    @improved_information = ValueSet.new
	    @needed_information   = ValueSet.new
	    @interruptible	  = nil
	end

	# Shortcut to set both model and argument 
	def which_fullfills(model, arguments = nil)
	    with_model(model).with_model_arguments(arguments || {})
	end

	# Find by model
	def with_model(model)
	    @model = model
	    self
	end
	
	# Find by arguments defined by the model
	def with_model_arguments(arguments)
	    if !model
		raise ArgumentError, "set model first"
	    end
	    with_arguments(arguments.slice(*model.arguments))
	    self
	end

	# Find by argument (exact matching)
	def with_arguments(arguments)
	    @arguments ||= Hash.new
	    self.arguments.merge!(arguments) do |k, old, new| 
		if old != new
		    raise ArgumentError, "a constraint has already been set on the #{k} argument" 
		end
		old
	    end
	    self
	end

	# Find tasks which improves information contained in +info+
	def which_improves(*info)
	    improved_information.merge(info.to_value_set)
	    self
	end

	# Find tasks which need information contained in +info+
	def which_needs(*info)
	    needed_information.merge(info.to_value_set)
	    self
	end

        # Finds by owners. The set of owner is added to any owner already
        # added. Do
        #
        #   matcher.owners.clear
        #
        # to remove all owners
	def owned_by(*ids)
	    @owners |= ids
	    self
	end

        # Finds tasks which we own ourselves.
	def self_owned
	    owned_by(Roby::Distributed)
	    self
	end

	class << self
	    def declare_class_methods(*names) # :nodoc:
		names.each do |name|
		    raise "no instance method #{name} on TaskMatcher" unless TaskMatcher.method_defined?(name)
		    TaskMatcher.singleton_class.send(:define_method, name) do |*args|
			TaskMatcher.new.send(name, *args)
		    end
		end
	    end

            # For each name in +names+, define a #name and a #not_name method.
            # If the first is called, the matcher will match only tasks whose
            # #name? method returns true.  If the second is called, the
            # opposite will be done.
	    def match_predicates(*names)
		names.each do |name|
		    class_eval <<-EOD
		    def #{name}
			if neg_predicates.include?(:#{name}?)
			    raise ArgumentError, "trying to match (#{name}? & !#{name}?)"
		        end
			predicates << :#{name}?
			self
		    end
		    def not_#{name}
			if predicates.include?(:#{name}?)
			    raise ArgumentError, "trying to match (#{name}? & !#{name}?)"
		        end
			neg_predicates << :#{name}?
			self
		    end
		    EOD
		end
		declare_class_methods(*names)
		declare_class_methods(*names.map { |n| "not_#{n}" })
	    end
	end
	match_predicates :executable, :abstract, :partially_instanciated, :fully_instanciated,
	    :pending, :running, :finished, :success, :failed, :interruptible, :finishing

        # True if +task+ matches all the criteria defined on this object.
	def ===(task)
	    return unless task.kind_of?(Roby::Task)
	    if model
		return unless task.fullfills?(model)
	    end
	    if arguments
		return unless task.arguments.slice(*arguments.keys) == arguments
	    end

	    for info in improved_information
		return false if !task.improves?(info)
	    end
	    for info in needed_information
		return false if !task.needs?(info)
	    end
	    for pred in predicates
		return false if !task.send(pred)
	    end
	    for pred in neg_predicates
		return false if task.send(pred)
	    end

	    return false if !owners.empty? && !(task.owners - owners).empty?
	    true
	end

        # Filters the tasks in +initial_set+ by using the information in
        # +task_index+, and returns the result. The resulting set must
        # include all tasks in +initial_set+ which match with #===, but can
        # include tasks which do not match #===
	def filter(initial_set, task_index)
	    if model
		initial_set &= task_index.by_model[model]
	    end

	    if !owners.empty?
		for o in owners
		    if candidates = task_index.by_owner[o]
			initial_set &= candidates
		    else
			return ValueSet.new
		    end
		end
	    end

	    for pred in (predicates & TaskIndex::STATE_PREDICATES)
		initial_set &= task_index.by_state[pred]
	    end

	    for pred in (neg_predicates & TaskIndex::STATE_PREDICATES)
		initial_set -= task_index.by_state[pred]
	    end

	    initial_set
	end

        # Enumerates all tasks of +plan+ which match this TaskMatcher object
	def each(plan, &block)
	    plan.query_each(plan.query_result_set(self), &block)
	    self
	end

	# Define singleton classes. For instance, calling TaskMatcher.which_fullfills is equivalent
	# to TaskMatcher.new.which_fullfills
	declare_class_methods :which_fullfills, 
	    :with_model, :with_arguments, 
	    :which_needs, :which_improves, 
	    :owned_by, :self_owned

        # Returns the negation of this predicate
	def negate; NegateTaskMatcher.new(self) end
        # Combines this predicate with another using a AND logical operation
	def &(other); AndTaskMatcher.new(self, other) end
        # Combines this predicate with another using an OR logical operation
	def |(other); OrTaskMatcher.new(self, other) end
    end

    # A query is a predicate on both the task internal properties, and their
    # plan-related properties as well.
    class Query < TaskMatcher
        # The plan this query acts on
	attr_reader :plan

        # Create a query object on the given plan
	def initialize(plan)
	    @plan = plan
	    super()
	    @plan_predicates = Array.new
	    @neg_plan_predicates = Array.new
	end

        # The set of tasks which match in plan. This is a cached value, so use
        # #reset to actually recompute this set.
	def result_set
	    @result_set ||= plan.query_result_set(self)
	end

        # #result_set is a cached value. Call this method to reinitialize,
        # making sure the result set is recomputed next time #result_set is
        # called.
	def reset
	    @result_set = nil
	    self
	end

        # The set of predicates of Plan which must return true for #=== to
        # return true
	attr_reader :plan_predicates
        # The set of predicates of Plan which must return false for #=== to
        # return true.
	attr_reader :neg_plan_predicates

	class << self
            # For each name in +names+, define the #name and #not_name methods
            # on Query objects. When one of these methods is called on a Query
            # object, plan.name?(task) must return true (resp. false) for the
            # task to match.
	    def match_plan_predicates(*names)
		names.each do |name|
		    class_eval <<-EOD
		    def #{name}
			if neg_plan_predicates.include?(:#{name}?)
			    raise ArgumentError, "trying to match (#{name}? & !#{name}?)"
		        end
			plan_predicates << :#{name}?
			self
		    end
		    def not_#{name}
			if plan_predicates.include?(:#{name}?)
			    raise ArgumentError, "trying to match (#{name}? & !#{name}?)"
		        end
			neg_plan_predicates << :#{name}?
			self
		    end
		    EOD
		end
	    end
	end
	match_plan_predicates :mission, :permanent
	
        # Returns the set of tasks from the query for which no parent in
        # +relation+ can be found in the query itself
	def roots(relation)
	    @result_set = plan.query_roots(result_set, relation)
	    self
	end

        # True if +task+ matches the query. Call #result_set to have the set of
        # tasks which match in the given plan.
	def ===(task)
	    return unless super

	    for pred in plan_predicates
		return unless plan.send(pred, task)
	    end
	    for neg_pred in neg_plan_predicates
		return if plan.send(neg_pred, task)
	    end
	    true
	end

        # Iterates on all the tasks in the given plan which match the query
	def each(&block)
	    plan.query_each(result_set, &block)
	    self
	end
	include Enumerable
    end

    # This task combines multiple task matching predicates through a OR boolean
    # operator.
    class OrTaskMatcher < TaskMatcher
        # Create a new OrTaskMatcher object combining the given predicates.
	def initialize(*ops)
	    @ops = ops 
	    super()
	end

        # Filters as much as non-matching tasks as possible out of +task_set+,
        # based on the information in +task_index+
	def filter(task_set, task_index)
	    result = ValueSet.new
	    for child in @ops
		result.merge child.filter(task_set, task_index)
	    end
	    result
	end

        # Add a new predicate to the combination
	def <<(op); @ops << op end
        # True if the task matches at least one of the underlying predicates
	def ===(task)
	    return unless @ops.any? { |op| op === task }
	    super
	end
    end

    # Negate a given task-matching predicate
    class NegateTaskMatcher < TaskMatcher
        # Create a new TaskMatcher which matches if and only if +op+ does not
	def initialize(op)
	    @op = op
	    super()
       	end

        # Filters as much as non-matching tasks as possible out of +task_set+,
        # based on the information in +task_index+
	def filter(initial_set, task_index)
	    # WARNING: the value returned by filter is a SUPERSET of the
	    # possible values for the query. Therefore, the result of
	    # NegateTaskMatcher#filter is NOT
	    #
	    #   initial_set - @op.filter(...)
	    initial_set
	end

        # True if the task matches at least one of the underlying predicates
	def ===(task)
	    return if @op === task
	    super
	end
    end

    # This task combines multiple task matching predicates through a AND boolean
    # operator.
    class AndTaskMatcher < TaskMatcher
        # Create a new AndTaskMatcher object combining the given predicates.
	def initialize(*ops)
	    @ops = ops 
	    super()
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
	    return unless @ops.all? { |op| op === task }
	    super
	end
    end

    class Plan
	# Returns a Query object on this plan
	def find_tasks(model = nil, args = nil)
	    q = Query.new(self)
	    if model || args
		q.which_fullfills(model, args)
	    end
	    q
	end

	# Called by TaskMatcher#result_set and Query#result_set to get the set
	# of tasks matching +matcher+
	def query_result_set(matcher)
	    result = ValueSet.new
	    for task in matcher.filter(known_tasks, task_index)
		result << task if matcher === task
	    end
	    result
	end

	# Called by TaskMatcher#each and Query#each to return the result of
	# this query on +self+
	def query_each(result_set, &block)
	    for task in result_set
		yield(task)
	    end
	end

	# Given the result set of +query+, returns the subset of tasks which
	# have no parent in +query+
	def query_roots(result_set, relation)
	    children = ValueSet.new
	    found    = ValueSet.new
	    for task in result_set
		next if children.include?(task)
		task_children = task.generated_subgraph(relation)
		found -= task_children
		children.merge(task_children)
		found << task
	    end
	    found
	end
    end

    class Transaction
	# Returns two sets of tasks, [plan, transaction]. The union of the two
	# is the component that would be returned by
	# +relation.generated_subgraphs(*seeds)+ if the transaction was
	# committed
	def merged_generated_subgraphs(relation, plan_seeds, transaction_seeds)
	    plan_set        = ValueSet.new
	    transaction_set = ValueSet.new
	    plan_seeds	      = plan_seeds.to_value_set
	    transaction_seeds = transaction_seeds.to_value_set

	    loop do
		old_transaction_set = transaction_set.dup
		transaction_set.merge(transaction_seeds)
		for new_set in relation.generated_subgraphs(transaction_seeds, false)
		    transaction_set.merge(new_set)
		end

		if old_transaction_set.size != transaction_set.size
		    for o in (transaction_set - old_transaction_set)
			if o.respond_to?(:__getobj__)
			    o.__getobj__.each_child_object(relation) do |child|
				plan_seeds << child unless self[child, false]
			    end
			end
		    end
		end
		transaction_seeds.clear

		plan_set.merge(plan_seeds)
		plan_seeds.each do |seed|
		    relation.each_dfs(seed, BGL::Graph::TREE) do |_, dest, _, kind|
			next if plan_set.include?(dest)
			if self[dest, false]
			    proxy = wrap(dest, false)
			    unless transaction_set.include?(proxy)
				transaction_seeds << proxy
			    end
			    relation.prune # transaction branches must be developed inside the transaction
			else
			    plan_set << dest
			end
		    end
		end
		break if transaction_seeds.empty?

		plan_seeds.clear
	    end

	    [plan_set, transaction_set]
	end
	
	# Returns [plan_set, transaction_set], where the first is the set of
	# plan tasks matching +matcher+ and the second the set of transaction
	# tasks matching it. The two sets are disjoint.
	def query_result_set(matcher)
	    plan_set = ValueSet.new
	    for task in plan.query_result_set(matcher)
		plan_set << task unless self[task, false]
	    end
	    
	    transaction_set = super
	    [plan_set, transaction_set]
	end

	# Yields tasks in the result set of +query+. Unlike Query#result_set,
	# all the tasks are included in the transaction
	def query_each(result_set)
	    plan_set, trsc_set = result_set
	    plan_set.each { |task| yield(self[task]) }
	    trsc_set.each { |task| yield(task) }
	end

	# Given the result set of +query+, returns the subset of tasks which
	# have no parent in +query+
	def query_roots(result_set, relation)
	    plan_set      , trsc_set      = *result_set
	    plan_result   , trsc_result   = ValueSet.new     , ValueSet.new
	    plan_children , trsc_children = ValueSet.new     , ValueSet.new

	    for task in plan_set
		next if plan_children.include?(task)
		task_plan_children, task_trsc_children = 
		    merged_generated_subgraphs(relation, [task], [])

		plan_result -= task_plan_children
		trsc_result -= task_trsc_children
		plan_children.merge(task_plan_children)
		trsc_children.merge(task_trsc_children)

		plan_result << task
	    end

	    for task in trsc_set
		next if trsc_children.include?(task)
		task_plan_children, task_trsc_children = 
		    merged_generated_subgraphs(relation, [], [task])

		plan_result -= task_plan_children
		trsc_result -= task_trsc_children
		plan_children.merge(task_plan_children)
		trsc_children.merge(task_trsc_children)

		trsc_result << task
	    end

	    [plan_result, trsc_result]
	end
    end
end
