$LOAD_PATH.unshift File.expand_path('lib', File.dirname(__FILE__))
require 'enumerator'
require 'hoe'
require 'roby/config'

begin
    require 'hoe'
    namespace 'dist' do
        hoe = Hoe.new('roby', Roby::VERSION) do |p|
            p.developer 'Sylvain Joyeux', 'sylvain.joyeux@m4x.org'

            p.summary = 'A plan-based control framework for autonomous systems'
            p.url         = p.paragraphs_of('README.txt', 1).join("\n\n")
            p.description = p.paragraphs_of('README.txt', 2..18).join("\n\n")
            p.changes     = p.paragraphs_of('History.txt', 0..1).join("\n\n")
            p.post_install_message = p.paragraphs_of('README.txt', 2).join("\n\n")

            p.extra_deps << ['facets', '>= 2.0'] << 'activesupport' << ['utilrb', '1.2']
            if p.respond_to? :need_rdoc=
                p.need_rdoc = false
            end
        end
	hoe.spec.extensions << 
	    'ext/droby/extconf.rb' <<
	    'ext/graph/extconf.rb'

        hoe.spec.extra_rdoc_files =
            hoe.spec.files.grep /(\.rdoc|\.cc|\.hh|\.rb|\.txt)$/

        hoe.spec.description = hoe.summary
            
        hoe.spec.rdoc_options << 
            '--main' << 'README.txt' <<
            "--inline-source" << 
            "--accessor" << "attribute" << 
            "--accessor" << "attr_predicate"

	if !hoe.respond_to? :need_rdoc=
	    # This sucks, I know, but Hoe's handling of documentation is not
	    # enough for me
	    tasks = Rake.application.instance_variable_get :@tasks
	    tasks.delete_if { |n, _| n =~ /dist:(re|clobber_|)docs/ }
	end
    end
rescue LoadError
    puts "cannot load the Hoe gem, distribution is disabled"
end

def build_extension(name, soname = name)
    Dir.chdir("ext/#{name}") do
	extconf = "ruby extconf.rb"
	extconf << " --with-boost-dir=#{ENV['BOOST_DIR']}" if ENV['BOOST_DIR']
	if !system(extconf) || !system("make")
	    raise "cannot set up #{name} extension"
	end
    end
    FileUtils.ln_sf "../ext/#{name}/#{soname}.so", "lib/#{soname}.so"
end
def clean_extension(name, soname = name)
    puts "Cleaning ext/#{name}"
    Dir.chdir("ext/#{name}") do
	FileUtils.rm_f ["#{soname}.so", 'Makefile', 'mkmf.log']
	FileUtils.rm_f Dir.enum_for(:glob, '*.o').to_a
    end
end

task :cruise => [:setup, :recore_docs, :test]

#########
# Test-related targets

desc 'run all tests'
task :test => ['test:core', 'test:distributed']

namespace 'test' do
    desc 'run tests on the Core'
    task 'core' => :setup do
        if !system("testrb test/suite_core.rb")
            puts "failed core suite"
            exit(1)
        end
    end
    desc 'run tests on Distributed Roby'
    task 'distributed' => :setup do
        if !system("testrb test/suite_distributed.rb")
            puts "failed droby suite"
            exit(1)
        end
    end
end

desc 'generate and build all the necessary files'
task :setup => :uic do
    build_extension 'droby', 'roby_marshalling'
    build_extension 'graph', 'roby_bgl'
end

desc 'remove all generated files'
task :clean => 'dist:clean' do
    clean_extension 'droby'
    clean_extension 'graph', 'bgl'
end

UIFILES = %w{relations.ui relations_view.ui data_displays.ui replay_controls.ui basic_display.ui chronicle_view.ui}
desc 'generate all Qt UI files using rbuic4'
task :uic do
    UIFILES.each do |file|
	file = 'lib/roby/log/gui/' + file
	if !system('rbuic4', '-o', file.gsub(/\.ui$/, '_ui.rb'), file)
	    STDERR.puts "Failed to generate #{file}"
	end
    end
end

###########
# Documentation generation
#
# This redefines Hoe's targets for documentation, as the documentation
# generation is not flexible enough for us
namespace 'doc' do
    require 'roby/app/rake'
    Rake::RDocTask.new("core") do |rdoc|
      rdoc.options << "--inline-source" << "--accessor" << "attribute" << "--accessor" << "attr_predicate"
      rdoc.rdoc_dir = 'doc/rdoc/core'
      rdoc.title    = "Roby Core"
      rdoc.template = Roby::Rake.rdoc_template
      rdoc.options << '--main' << 'README.txt'
      rdoc.rdoc_files.include('README.txt', 'TODO.txt', 'History.txt')
      rdoc.rdoc_files.include('lib/**/*.rb', 'ext/**/*.cc')
      rdoc.rdoc_files.include('doc/videos.rdoc', 'doc/papers.rdoc')
      rdoc.rdoc_files.include('doc/tutorials/**/*')
      rdoc.rdoc_files.exclude('lib/roby/test/**/*', 'lib/roby/app/**/*', 'lib/roby/log/gui/*')
    end

    Rake::RDocTask.new("tutorials") do |rdoc|
      rdoc.options << "--inline-source" << "--accessor" << "attribute" << "--accessor" << "attr_predicate"
      rdoc.rdoc_dir = 'doc/rdoc/tutorials'
      rdoc.title    = "Roby Tutorials"
      rdoc.template = Roby::Rake.rdoc_template
      rdoc.options << '--main' << 'README.txt'
      rdoc.rdoc_files.include('README.txt', 'TODO.txt', 'History.txt')
      rdoc.rdoc_files.include('doc/videos.rdoc', 'doc/papers.rdoc')
      rdoc.rdoc_files.include('doc/tutorials/**/*')
    end

    def plugins_documentation_generation(target_prefix)
        task "plugins_#{target_prefix}docs" do
            Roby::Rake.invoke_plugin_target("#{target_prefix}docs")
        end
    end
    desc 'generate the documentation for all installed plugins'
    plugins_documentation_generation ''
    desc 'remove the documentation for all installed plugins'
    plugins_documentation_generation 'clobber_'
    desc 'regenerate the documentation for all installed plugins'
    plugins_documentation_generation 're'
end

task 'docs' => ['doc:core', 'doc:plugins_docs']
task 'clobber_docs' => ['doc:clobber_core', 'doc:plugins_clobber_docs']
task 'redocs' => ['doc:recore', 'doc:replugins_docs']