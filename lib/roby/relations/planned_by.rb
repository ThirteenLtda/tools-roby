require 'roby/task'

module Roby::TaskStructure
    relation :PlannedBy, :child_name => :planning_task, 
	:parent_name => :planned_task, :noinfo => true, :single_child => true do

	# The set of tasks which are planned by this one
	def planned_tasks; parent_objects(PlannedBy) end
	# Set +task+ as the planning task of +self+
        def planned_by(task, options = {})
	    if old = planning_task
		if options[:replace]
		    remove_planning_task(old)
		else
		    raise ArgumentError, "this task already has a planner"
		end
	    end
	    add_planning_task(task)
        end
    end

    # Returns a set of PlanningFailedError exceptions for all abstract tasks
    # for which planning has failed
    def PlannedBy.check_structure(plan)
	result = []
	Roby::TaskStructure::PlannedBy.each_edge do |planned_task, planning_task, _|
	    next unless plan == planning_task.plan && planning_task.failed?
	    next unless planned_task.pending? && !planned_task.executable? && planned_task.self_owned?
	    result << Roby::PlanningFailedError.new(planned_task, planning_task)
	end

	result
    end
end

module Roby
    # This exception is raised when a task is abstract, and its planner failed:
    # the system will therefore not have a suitable executable development for
    # this task, and this is a failure
    class PlanningFailedError < LocalizedError
	# The planning task
	attr_reader :planned_task

	def initialize(planned_task, planning_task)
	    @planned_task = planned_task
	    super(planning_task.terminal_event)
	end

	def message # :nodoc:
	    msg = "failed to plan #{planned_task}.planned_by(#{failed_task}): failed with #{failure_point.symbol}"
	    if failure_point.context
		if failure_point.context.first.respond_to?(:full_message)
		    msg << "\n" << failure_point.context.first.full_message
		else
		    msg << "(" << failure_point.context.first.to_s << ")"
		end
	    end
	    msg
	end
    end
end
