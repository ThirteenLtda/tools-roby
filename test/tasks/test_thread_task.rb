require 'roby/test/self'
require 'roby/tasks/thread'

class TC_ThreadTask < Minitest::Test 
    # Starts +task+ and waits for the thread to end
    def wait_thread_end(task)
        task.start!
        while task.thread
            process_events
            sleep 0.1
        end
    end

    def test_normal
        model = Roby::Tasks::Thread.new_submodel do
            implementation do
                1
            end
        end

        plan.add_mission_task(task = model.new)
	wait_thread_end(task)

        assert task.success?
        assert_equal 1, task.result
    end

    def test_implementation_fails
        Thread.abort_on_exception = false
        Roby.app.abort_on_exception = false
        model = Roby::Tasks::Thread.new_submodel do
            implementation do
                raise ArgumentError, "blaaaaaaaaah"
            end
        end

        plan.add_permanent_task(task = model.new)
        inhibit_fatal_messages do
            wait_thread_end(task)
        end

        assert task.failed?
        assert_kind_of ArgumentError, task.event(:failed).last.context.first
        assert_equal nil, task.result
    end

    def test_interruptible
        Thread.abort_on_exception = false
        model = Roby::Tasks::Thread.new_submodel do
            interruptible
            implementation do
                loop do
                    interruption_point
                    sleep 0.1
                end
            end
        end

        plan.add(task = model.new)
	wait_thread_end(task)

        assert task.failed?
        assert_kind_of Interrupt, task.event(:failed).last.context.first
        assert_equal nil, task.result
    end
end

