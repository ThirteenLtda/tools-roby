module Roby
    module Coordination
        module Models

        # State whose instanciation object is provided through a state machine
        # variable
        class TaskFromVariable < TaskWithDependencies
            attr_reader :variable_name
            def initialize(variable_name, task_model)
                @variable_name = variable_name
                super(task_model)
            end

            def instanciate(plan, variables = Hash.new)
                obj = variables[variable_name]
                if !obj.respond_to?(:instanciate)
                    raise ArgumentError, "expected variable #{variable_name} to contain an object that can generate tasks, found #{obj}"
                end
                obj.instanciate(plan)
            end

            def to_s; "var(#{variable_name})[#{task_model}]" end
        end
        end
    end
end

