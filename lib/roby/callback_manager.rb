module Roby
    # Management of one set of {CallbackDefinition}
    #
    # It encapsulates the ability to add and remove blocks while processing.
    # Addition and removal is thread-safe.
    class CallbackManager
        # Whether adding and removing handlers should act at the point of
        # call, or during the next call to {#process}
        #
        # Handler sets are not immediate by default
        attr_predicate :immediate?, true

        def initialize(immediate: false)
            @immediate = immediate
            @handlers = Hash.new
            @add_remove_sync = Mutex.new
            @add_queue = Hash.new
            @remove_queue = Array.new
        end

        # Add a new handler
        #
        # @param [CallbackDefinition] handler
        # @return [Object] an ID for the handler, that can be passed to
        #   {#remove}
        def add(handler)
            handler_id = handler.object_id
            @add_remove_sync.synchronize do
                @remove_queue.delete(handler_id)
                @add_queue[handler_id] = handler
            end
            handler_id
        end

        # Remove a handler
        def remove(handler_id)
            @add_remove_sync.synchronize do
                @add_queue.delete(handler_id)
                @remove_queue << handler_id
            end
        end

        # @api private
        #
        # Actually removes the entries in the callback list
        #
        # The method itself is unsynchronized. It must be protected by
        # @add_remove_sync
        def process_remove_queue
            @remove_queue.each do |handler_id|
                handlers.delete(handler_id)
            end
            @remove_queue.clear
        end

        # @api private
        #
        # Actually adds the entries in the callback list
        #
        # The method itself is unsynchronized. It must be protected by
        # @add_remove_sync
        def process_add_queue
            # We do not use merge! as it has no ordering guarantees, and we
            # want callback call order to match insertion order
            @add_queue.each do |handler_id, handler|
                @handlers[handler_id] = handler
            end
            @add_queue.clear
        end

        # Process these handlers
        #
        # @param [ExecutionEngine] execution_engine the underlying execution
        #   engine. It is used to register errors
        # @param [Array] args arguments that should be passed to the block
        def process(execution_engine, *args)
            queue = @handlers
            begin
                queue.delete_if do |handler|
                    if @remove_queue.include?(handler.object_id)
                        true
                    elsif !handler.call(*args)
                        handler.disabled = true
                        false
                    end
                end
            end while !immediate? || queue.empty?
        end
    end
end
