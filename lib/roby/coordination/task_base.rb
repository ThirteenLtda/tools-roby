module Roby
    module Coordination
            class ResolvingUnboundObject < RuntimeError; end

            # Base functionality for task-like objects in coordination models
            # (Task, Child)
            class TaskBase
                # @return [Base] the underlying execution context
                attr_reader :execution_context
                # @return [Coordination::Models::Task]
                attr_reader :model

                def initialize(execution_context, model)
                    @execution_context = execution_context
                    @model = model
                end

                # Method that must be reimplemented in the task objects actually
                # used in the coordination primitives
                def resolve
                    raise NotImplementedError, "#resolve must be reimplemented in objects meant to be used in the coordination primitives"
                end

                def find_child(role, child_model = nil)
                    child_model ||= model.find_child_model(role)
                    if !child_model
                        begin
                            task = self.resolve
                            if child_task = task.find_child_from_role(role)
                                child_model = child_task.model
                            end
                        rescue ResolvingUnboundObject
                        end
                    end

                    if child = model.find_child(role, child_model)
                        execution_context.instance_for(child)
                    end
                end

                def find_event(symbol)
                    if event = model.find_event(symbol)
                        execution_context.instance_for(event)
                    end
                end

                def method_missing(m, *args, &block)
                    case m.to_s
                    when /(.*)_child$/
                        if !args.empty?
                            raise ArgumentError, "expected zero arguments, got #{args.size}"
                        elsif child = find_child($1)
                            child
                        else raise NoMethodError.new("#{self} has no child named #{$1}", m)
                        end
                    when /(.*)_event$/
                        if !args.empty?
                            raise ArgumentError, "expected zero arguments, got #{args.size}"
                        elsif event = find_event($1)
                            event
                        else raise NoMethodError.new("#{self} has no event named #{$1}", m)
                        end
                    else super
                    end
                end

                def to_coordination_task(task_model); model.to_coordination_task(task_model) end
            end
    end
end


