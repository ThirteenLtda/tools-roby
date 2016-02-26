require 'roby/log/logger'

module Roby::Log
    module DistributedObjectHooks
	HOOKS = %w{added_owner removed_owner}

	def added_owner(peer)
	    super if defined? super
	    Roby::Log.log(:added_owner) { [self, peer] }
	end

	def removed_owner(peer)
	    super if defined? super
	    Roby::Log.log(:removed_owner) { [self, peer] }
	end
    end
    Roby::DistributedObject.include DistributedObjectHooks

    module TaskHooks
	HOOKS = %w{added_task_child removed_task_child task_failed_to_start updated_task_relation}

	def updated_edge_info(child, relation, info)
	    super if defined? super
	    Roby::Log.log(:updated_task_relation) { [self, relation, child, info] }
	end

	def added_child_object(child, relations, info)
	    super if defined? super
	    Roby::Log.log(:added_task_child) { [self, relations, child, info] }
	end

	def removed_child_object(child, relations)
	    super if defined? super
	    Roby::Log.log(:removed_task_child) { [self, relations, child] }
	end

        def failed_to_start(reason)
            super if defined? super
	    Roby::Log.log(:task_failed_to_start) { [self, reason] }
        end
    end
    Roby::Task.include TaskHooks

    module PlanHooks
	HOOKS = %w{
            added_mission unmarked_mission
            added_permanent unmarked_permanent
            added_tasks added_events finalized_task finalized_event
            replaced_tasks garbage added_transaction removed_transaction}

	def added_mission(tasks)
	    super if defined? super
	    Roby::Log.log(:added_mission) { [self, tasks] }
	end
	def unmarked_mission(tasks)
	    super if defined? super
	    Roby::Log.log(:unmarked_mission) { [self, tasks] }
	end
	def replaced(from, to)
	    super if defined? super
	    Roby::Log.log(:replaced_tasks) { [self, from, to] }
	end
	def added_events(tasks)
	    super if defined? super
	    Roby::Log.log(:added_events) { [self, tasks] }
	end
	def added_tasks(tasks)
	    super if defined? super
	    Roby::Log.log(:added_tasks) { [self, tasks] }
	end
	def garbage(object)
	    super if defined? super
	    Roby::Log.log(:garbage) { [self, object] }
	end
	def finalized_event(event)
	    super if defined? super
	    Roby::Log.log(:finalized_event) { [self, event] }
	end
	def finalized_task(task)
	    super if defined? super
	    Roby::Log.log(:finalized_task) { [self, task] }
	end

	def added_transaction(trsc)
	    super if defined? super
	    Roby::Log.log(:added_transaction) { [self, trsc] }
	end
	def removed_transaction(trsc)
	    super if defined? super
	    Roby::Log.log(:removed_transaction) { [self, trsc] }
	end
    end
    Roby::Plan.include PlanHooks

    module TransactionHooks
	HOOKS = %w{committed_transaction discarded_transaction}

	def committed_transaction
	    super if defined? super
	    Roby::Log.log(:committed_transaction) { [self] }
	end
	def discarded_transaction
	    super if defined? super
	    Roby::Log.log(:discarded_transaction) { [self] }
	end
    end
    Roby::Transaction.include TransactionHooks

    module EventGeneratorHooks
	HOOKS = %w{added_event_child removed_event_child 
		   generator_calling generator_called generator_fired
		   generator_signalling generator_forwarding generator_emitting
		   generator_postponed generator_emit_failed}

	def added_child_object(to, relations, info)
	    super if defined? super
	    Roby::Log.log(:added_event_child) { [self, relations, to, info] }
	end

	def removed_child_object(to, relations)
	    super if defined? super
	    Roby::Log.log(:removed_event_child) { [self, relations, to] }
	end

	def updated_edge_info(child, relation, info)
	    super if defined? super
	    Roby::Log.log(:updated_event_relation) { [self, relation, child, info] }
	end

	def calling(context)
	    super if defined? super
	    Roby::Log.log(:generator_calling) { [self, plan.engine.propagation_source_generators, context.to_s] }
	end

	def called(context)
	    super if defined? super
	    Roby::Log.log(:generator_called) { [self, context.to_s] }
	end

	def fired(event)
	    super if defined? super
	    Roby::Log.log(:generator_fired) { [self, event.object_id, event.time, event.context.to_s] }
	end

        def failed_to_emit(error)
	    super if defined? super
	    Roby::Log.log(:generator_emit_failed) { [self, error] }
	end

	def signalling(event, to)
	    super if defined? super
	    Roby::Log.log(:generator_signalling) { [false, self, to, event.object_id, event.time, event.context.to_s] }
	end

	def emitting(context)
	    super if defined? super
	    Roby::Log.log(:generator_emitting) { [self, plan.engine.propagation_source_generators, context.to_s] }
	end

	def forwarding(event, to)
	    super if defined? super
	    Roby::Log.log(:generator_forwarding) { [true, self, to, event.object_id, event.time, event.context.to_s] }
	end

    end
    Roby::EventGenerator.include EventGeneratorHooks

    module ExecutionHooks
	HOOKS = %w{cycle_end fatal_exception handled_exception nonfatal_exception report_scheduler_state}

	def cycle_end(timings)
	    super if defined? super
	    Roby::Log.log(:cycle_end) { [timings] }
	end

        def nonfatal_exception(error, tasks)
            super if defined? super
	    Roby::Log.log(:nonfatal_exception) { [error.exception, tasks] }
        end

        def fatal_exception(error, tasks)
            super if defined? super
            Roby::Log.log(:fatal_exception) { [error.exception, tasks] }
        end
        def handled_exception(error, task)
            super if defined? super
            Roby::Log.log(:handled_exception) { [error.exception, task] }
        end
        def report_scheduler_state(state)
            super if defined? super
            Roby::Log.log(:report_scheduler_state) { [plan, state.pending_non_executable_tasks, state.called_generators, state.non_scheduled_tasks] }
        end
    end
    Roby::ExecutionEngine.include ExecutionHooks

    module TaskArgumentsHooks
        HOOKS=%w{task_arguments_updated}

        def updated(key, value)
            super if defined? super
            Roby::Log.log(:task_arguments_updated) { [task, key, value] }
        end
    end
    Roby::TaskArguments.include TaskArgumentsHooks

    class << self
        # Hooks that need to be registered for the benefit of generic loggers
        # such as {FileLogger}
        attr_reader :additional_hooks

        # Generic logging classes, e.g. that should log all log messages
        attr_reader :generic_loggers
    end
    @generic_loggers = Array.new
    @additional_hooks = Array.new

    def self.register_generic_logger(klass)
        each_hook do |m|
            klass.define_hook m
        end
        generic_loggers << klass
    end

    # Define a new logging hook (logging method) that should be logged on all
    # generic loggers
    def self.define_hook(m)
        additional_hooks << m
        generic_loggers.each do |l|
            l.define_hook(m)
        end
    end

    def self.each_hook
        # Note: in ruby 2.1+, we can get rid of this by having a decorator API
        #
        #   Log.define_hook def cycle_end(timings)
        #      ...
        #   end
	[TransactionHooks, DistributedObjectHooks, TaskHooks,
	    PlanHooks, EventGeneratorHooks, ExecutionHooks, TaskArgumentsHooks].each do |klass|
		klass::HOOKS.each do |m|
		    yield(m.to_sym)
		end
	    end

        additional_hooks.each do |m|
            yield(m)
        end
    end
end

