require 'roby/log/data_stream'

class Roby::Task::DRoby
    attr_accessor :mission
end

module Roby
    module Log
	class Notifications < Roby::Log::DataDecoder
	    GENERATOR_CALL_LIMIT = 0.1

	    attr_reader :tasks

	    attr_reader :histories
	    def initialize(name)
		@tasks     = Hash.new
		@histories = Hash.new { |h, k| h[k] = Array.new }
		super(name)
	    end

	    def added_task(task)
		task.remote_siblings.each_value do |id|
		    tasks[id] = task
		end
	    end
	    def removed_task(remote_id)
		task = tasks.delete(remote_id)
		task.remote_siblings.each_value do |id|
		    tasks.delete(id)
		end
	    end

	    def clear
		super

		@tasks.clear
		@histories.clear
	    end


	    def process(data)
		data.each_slice(4) do |m, sec, usec, args|
		    time = Time.at(sec, usec)
		    case m.to_s
		    when /inserted/
			task = tasks[args[1]]
			task.mission = true
			event :added_mission, args[0], task

		    when /discarded/
			task = tasks[args[1]]
			task.mission = false
			event :discarded_mission, args[0], task

		    when /discovered_tasks/
			args[1].each { |t| added_task(t) }

		    when /finalized_task/
			id = args[1]
			task = tasks[id]
			if histories[id].empty?
			    event :finalized_pending, time, task
			end
			histories.delete(task)
			removed_task(args[1])

		    when /generator_calling/
			@current_call = [time, args[0]]

		    when /generator_called/
			if @current_call[1] == args[0]
			    duration = time - @current_call[0]
			    if duration > GENERATOR_CALL_LIMIT
				event :overly_long_call, time, duration, tasks[args[0].task], args[0].symbol, args[1]
			    end
			end
			
		    when /exception/
			error, involved_tasks = *args
			involved_tasks = involved_tasks.map { |id| tasks[id] }
			event m, time, error, involved_tasks
		    when /generator_fired/
			generator = args[0]
			if generator.respond_to?(:task)
			    histories[generator.task] << args
			    if generator.symbol == :failed
				event :failed_task, time, tasks[generator.task], histories[generator.task]
			    end
			end
		    end
		end
	    end

	    def event(name, *args)
		displays.each do |display|
		    if display.respond_to?(name)
			display.send(name, *args)
		    end
		end
	    end
	end

	class NotificationsDisplay < Qt::TextBrowser
	    include DataDisplay
	    decoder Notifications

	    attr_reader :document
	    attr_reader :text

	    STYLESHEET = <<-EOS
		    h1 { font-size: large; }
		    h1 { margin-bottom: 3px; }
		    h2 { font-size: medium; }
		    .time { 
			margin-right: 10px; 
		    }

		    div.info {
			color: black;
			margin-top: 20px;
			border-top: thin solid black;
		    }
		    div.info h1 { margin-top: 0; background-color: #5FB86A; }
		    div.warn { 
			color: black;
			margin-top: 20px;
			border-top: thin solid black; 
		    }
		    div.warn h1 { margin-top: 0; background-color: #B8AC5F; }
		    div.error { 
			color: black;
			margin-top: 20px;
			border-top: thin solid black; 
		    }
		    div.error h1 { margin-top: 0; background-color: #B8937D; }
	    EOS

	    def initialize
		super()

		resize(500, 600)
		@main     = self
		@document = Qt::TextDocument.new

		self.document = document
		document.setDefaultStyleSheet(STYLESHEET)
	    end


	    def render_event(kind, time, title)
		@text = ""
		text << "\n<div class=#{kind}>\n  <h1><span class=\"time\">#{time.to_hms}</span> #{title}</h1>\n  "
		yield

	    ensure
		text << "\n</div>"
		insertHtml(text)
		verticalScrollBar.value = verticalScrollBar.maximum
	    end

	    def render_task(task)
		remote_siblings = "{ " << task.remote_siblings.map { |peer, id| id.to_s(peer) }.join(", ") << " }"
		text << "<div class=\"task\">
		    #{task.model.ancestors.first.first}#{remote_siblings}\n  "
		
		unless task.arguments.empty?
		    text << "<ul class=\"task-arguments\">\n    "
		    task.arguments.each do |key, value|
			text << "    <li>#{key}: #{value}<li>\n"
		    end
		    text << "  </ul>\n"
		end
		text << "</div>"
	    end

	    def render_history(history)
		text << "<ul class=\"history\">\n"
		history.each do |generator, id, time, context|
		    text << "<li>#{time.to_hms} #{generator.symbol} [#{context}]</li>"
		end
		text << "</ul>"
	    end

	    def clear
		document.clear
	    end

	    def finalized_pending(time, task)
		render_event("warn", time, "Finalized pending task") do
		    render_task(task)
		end
	    end
	    def added_mission(time, task)
		render_event("info", time, "New mission") do
		    render_task(task)
		end
	    end
	    def removed_mission(time, task)
		render_event("info", time, "Removed mission") do
		    render_task(task)
		end
	    end
	    def render_error(error, tasks)
		error = Qt.escape(error.to_s)
		error = error.split("\n").map do |line|
		    line.gsub(/^\s+/) { "&nbsp;" * $&.size }
		end.join("<br>")

		text << error
		text << "<h2>Involved tasks</h2>"
		text << "<ul>"
		tasks.each do |t| 
		    text << "<li>"
		    render_task(t) 
		    text << "</li>"
		end
	    end

	    def fatal_exception(time, error, tasks)
		render_event("error", time, "Fatal exception") do
		    render_error(error, tasks)
		end
	    end
	    def handled_exception(time, error, tasks)
		render_event("warn", time, "Handled exception") do
		    render_error(error, tasks)
		end
	    end
	    def failed_task(time, task, history)
		render_event("warn", time, "Failed task") do
		    render_task(task)
		    render_history(history)
		end
	    end
	    def overly_long_call(time, duration, task, event_name, context)
		render_event("warn", time, "Overly long call: ") do
		    text << "Call of #{event_name}(#{context}) lasted #{Integer(duration * 1000)}ms in<br>"
		    render_task(task)
		end
	    end
	end
    end
end
