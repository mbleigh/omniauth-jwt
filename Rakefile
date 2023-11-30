require "bundler/gem_tasks"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

desc "alias test task to spec"
task test: :spec

require "kettle-soup-cover"
Kettle::Soup::Cover.install_tasks

task default: :spec
