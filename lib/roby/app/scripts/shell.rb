require 'roby'
require 'roby/distributed'
require 'optparse'

remote_url = nil
opt = OptionParser.new do |opt|
    opt.on('--host URL', String, "sets the host to connect to") do |url|
	remote_url = url
    end
end
opt.parse! ARGV

app = Roby.app
app.shell
app.single

robot_name = ARGV.shift
app.robot robot_name, (ARGV.shift || robot_name)
app.setup

remote_url ||= app.droby['host']
remote_url ||= 'localhost'
if remote_url !~ /:\d+$/
    if app.droby['host'] && app.droby['host'] =~ /(:\d+)$/
	remote_url << $1
    else
	remote_url << ":#{Roby::Distributed::DEFAULT_DROBY_PORT}"
    end
end

DRb.start_service

require 'irb'
IRB.setup(nil)

control = Roby::RemoteInterface.new(DRbObject.new_with_uri("druby://#{remote_url}"))

begin
    # Make control the top-level object
    bind = control.instance_eval { binding }
    ws  = IRB::WorkSpace.new(bind)
    irb = IRB::Irb.new(ws)

    context = irb.context
    IRB.conf[:MAIN_CONTEXT] = irb.context

    trap("SIGINT") do
	irb.signal_handle
    end

    # Create a thread which reads the remote messages and display them if needed
    Thread.new do
	begin
	    loop do
		sleep(1)
		
		msg = begin
			  control.poll_messages
		      rescue DRb::DRbConnError
			  []
		      end

		if !msg.empty?
		    STDERR.puts
		    msg.each do |t| 
			STDERR.puts "!" + t.split("\n").join("\n!")
		    end
		end
	    end
	rescue
	    STDERR.puts $!.full_message
	ensure
	    STDERR.puts "message polling died"
	end
    end

    catch(:IRB_EXIT) do
	irb.eval_input
    end
end
