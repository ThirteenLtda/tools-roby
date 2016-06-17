require 'roby/tasks/timeout'
module Roby
    module Coordination
        module Models
            # The metamodel for all script-based coordination models
            module Script
                extend MetaRuby::Attributes

                class DeadInstruction < Roby::LocalizedError; end

                # Script element that implements {Script#start}
                class Start < Coordination::ScriptInstruction
                    attr_reader :task
                    attr_reader :dependency_options

                    def initialize(task, dependency_options)
                        @task = task
                        @dependency_options = dependency_options
                    end

                    def new(script)
                        Start.new(script.instance_for(task), dependency_options)
                    end

                    def execute(script)
                        script.start_task(task)
                        true
                    end

                    def to_s; "start(#{task}, #{dependency_options})" end
                end

                # Script element that implements {Script#wait}
                class Wait < Coordination::ScriptInstruction
                    attr_reader :event

                    # @return [Time,nil] time after which an emission is valid.
                    #   'nil' means that only emissions that have happened after
                    #   the script reached this instruction are considered
                    attr_reader :time_barrier

                    # @return [Float] number of seconds after which the wait
                    #   instruction should generate an error
                    attr_reader :timeout

                    # @return [Boolean] true if {#execute} has been called once
                    attr_predicate :initialized?

                    # @return [Boolean] true if the watched event got emitted
                    attr_predicate :done?

                    # @param [Time] after (nil) value for {#time_barrier}
                    def initialize(event, after: nil)
                        @event = event
                        @done = false
                        @time_barrier = after
                    end

                    def new(script)
                        Wait.new(script.instance_for(event), after: time_barrier)
                    end

                    def execute(script)
                        event = self.event.resolve

                        if time_barrier
                            last_event = event.history.last
                            if last_event && last_event.time > time_barrier
                                return true
                            end
                        end

                        if event.task != script.root_task
                            script.root_task.depends_on event.task, success: event.symbol
                        else
                            if event.unreachable?
                                raise DeadInstruction.new(script.root_task), "#{self} is locked: #{event.unreachability_reason}"
                            end
                            event.if_unreachable(cancel_at_emission: true) do |reason, generator|
                                if !disabled?
                                    raise DeadInstruction.new(script.root_task), "#{self} is locked: #{reason}"
                                end
                            end
                        end

                        event.on on_replace: :copy do |event|
                            if event.generator == self.event.resolve && !disabled?
                                if !time_barrier || event.time > time_barrier
                                    cancel
                                    script.step
                                end
                            end
                        end

                        false
                    end

                    def to_s; "wait(#{event})" end
                end

                # Script element that implements {Script#emit}
                class Emit < Coordination::ScriptInstruction
                    # @return [Event] the event that should be
                    # emitted
                    attr_reader :event

                    def initialize(event)
                        @event = event
                    end

                    def new(script)
                        Emit.new(script.instance_for(event))
                    end

                    def execute(script)
                        event.resolve.emit
                        true
                    end

                    def to_s; "emit(#{event})" end
                end

                class TimeoutStart
                    attr_reader :seconds
                    attr_reader :event

                    def initialize(seconds, emit: nil)
                        @seconds = seconds
                        @event = emit
                    end

                    def new(script)
                        event = if self.event
                                    script.instance_for(self.event)
                                end

                        Coordination::TaskScript::TimeoutStart.new(self, event)
                    end
                end

                class TimeoutStop
                    attr_reader :timeout_start

                    def initialize(timeout_start)
                        @timeout_start = timeout_start
                    end

                    def new(script)
                        Coordination::TaskScript::TimeoutStop.new(script.instance_for(timeout_start))
                    end
                end

                inherited_single_value_attribute('__terminal') { false }

                # Marks this script has being terminated, i.e. that no new
                # instructions can be added to it
                #
                # Once this is called, adding new instructions will raise
                # ArgumentError
                def terminal
                    __terminal(true)
                end

                # @return [Boolean] if true, this script cannot get new
                #   instructions (a terminal instruction has been added)
                def terminal?
                    __terminal
                end

                # The list of instructions in this script
                # @return [Array]
                attribute(:instructions) { Array.new }

                # Starts the given task
                #
                # @param [Task] task the action-task. It must be created by
                #   calling {Base#task} on the relevant object
                # @param [Hash] options the dependency relation options. See
                #   {Roby::TaskStructure::Dependency::Extension#depends_on}
                def start(task, options = Hash.new)
                    task = validate_or_create_task task
                    add Start.new(task, options)
                    wait(task.start_event)
                end

                # Starts the given task, and waits for it to successfully finish
                #
                # @param [Task] task the action-task. It must be created by
                #   calling {Base#task} on the relevant object
                # @param [Hash] options the dependency relation options. See
                #   {Roby::TaskStructure::Dependency::Extension#depends_on}
                def execute(task, options = Hash.new)
                    task = validate_or_create_task task
                    start(task, options)
                    wait(task.success_event)
                end

                # Waits a certain amount of time before continuing
                #
                # @param [Float] time the amount of time to wait, in seconds
                def sleep(time)
                    task = self.task(ActionCoordination::TaskFromAsPlan.new(Tasks::Timeout.with_arguments(delay: time), Tasks::Timeout))
                    start task
                    wait task.stop_event
                end

                # Waits until this event gets emitted
                #
                # It will wait even if this event has already been emitted at
                # this point in the script (i.e. waits for a "new" emission)
                #
                # @param [Event] event the event to wait for
                # @param [Hash] options
                # @option options [Float] timeout a timeout (for backward
                #   compatibility, use timeout(seconds) do ... end instead)
                def wait(event, options = Hash.new)
                    validate_event event

                    # For backward compatibility only
                    options, wait_options = Kernel.filter_options(options, timeout: nil)

                    wait = Wait.new(event, wait_options)
                    if options[:timeout]
                        timeout(options[:timeout]) do
                            add wait
                        end
                    else
                        add wait
                    end
                    wait
                end

                # Emit the given event
                #
                # @param [Event] event
                def emit(event)
                    validate_event event
                    add Emit.new(event)
                end

                # Execute another script at this point in the execution
                def call(script)
                    instructions.concat(script.instructions)
                end

                def timeout_start(delay, options = Hash.new)
                    ins = TimeoutStart.new(delay, options)
                    add ins
                    ins
                end

                def timeout_stop(timeout_start)
                    ins = TimeoutStop.new(timeout_start)
                    add ins
                    ins
                end

                def add(instruction)
                    if terminal?
                        raise ArgumentError, "a terminal command has been called on this script, cannot add anything further"
                    end
                    instructions << instruction
                end
            end
        end
    end
end
