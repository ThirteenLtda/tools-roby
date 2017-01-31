source 'https://rubygems.org'

gem 'activesupport', '< 5.0.0', platform: [:ruby_21]
gem 'rubigen', git: 'https://github.com/doudou/rubigen'
gem 'utilrb', git: 'https://github.com/orocos-toolchain/utilrb'
gem 'metaruby', git: 'https://github.com/rock-core/tools-metaruby', branch: 'syskit2'

platform :mri do
    group 'development' do
        gem 'stackprof'
        gem 'rbtrace'
    end
    group 'gui' do
        gem 'qtbindings'
    end
end
gem 'coveralls'

gemspec
