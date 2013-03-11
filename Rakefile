# encoding: utf-8

require 'rubygems'
require 'bundler'
require 'pathname'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "githooks"
  gem.homepage = "http://github.com/rabbitt/githooks"
  gem.license = "MIT"
  gem.summary = %Q{framework for building git hooks tests}
  gem.description = %Q{GitHooks provides a framework for building test that can be used with git hooks}
  gem.email = "rabbitt@gmail.com"
  gem.authors = ["Carl P. Corliss"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

require 'simplecov'

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:features)

task :default => :test

desc "Run RSpec with code coverage"
task :coverage do
  SimpleCov.start do
    root(Pathname.new(__FILE__).realpath.dirname)
  end
  system("open coverage/index.html")
end

require 'yard'
YARD::Rake::YardocTask.new
