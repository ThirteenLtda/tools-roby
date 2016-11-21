module Roby
    # Internal structure used to store a poll block definition provided to
    # #every or #add_propagation_handler
    class CallbackDefinition
        ON_ERROR = [:raise, :ignore, :disable]

        attr_reader :description
        attr_reader :handler
        attr_reader :on_error
        attr_predicate :late?, true
        attr_predicate :once?, true
        attr_predicate :disabled?, true

        def id; handler.object_id end

        def initialize(description, handler, on_error: :raise, late: false, once: false)
            if !CallbackDefinition::ON_ERROR.include?(on_error.to_sym)
                raise ArgumentError, "invalid value '#{on_error} for the :on_error option. Accepted values are #{ON_ERROR.map(&:to_s).join(", ")}"
            end

            @description, @handler, @on_error, @late, @once =
                description, handler, on_error, late, once
            @disabled = false
        end
    
        def to_s; "#<CallbackDefinition: #{description} #{handler} on_error:#{on_error}>" end

        def call(engine, *args)
            handler.call(*args)
            true

        rescue Exception => e
            if on_error == :raise
                engine.add_framework_error(e, description)
                return false
            elsif on_error == :disable
                ExecutionEngine.warn "propagation handler #{description} disabled because of the following error"
                Roby.log_exception_with_backtrace(e, ExecutionEngine, :warn)
                return false
            elsif on_error == :ignore
                ExecutionEngine.warn "ignored error from propagation handler #{description}"
                Roby.log_exception_with_backtrace(e, ExecutionEngine, :warn)
                return true
            end
        end
    end
end
