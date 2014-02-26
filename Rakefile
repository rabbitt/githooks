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
  gem.name = "githooker"
  gem.homepage = "http://github.com/rabbitt/githooker"
  gem.license = "GPLv2"
  gem.summary = %Q{framework for building git hooks tests}
  gem.description = %Q{GitHooker provides a framework for building test that can be used with git hooks}
  gem.email = "rabbitt@gmail.com"
  gem.authors = ["Carl P. Corliss"]
  gem.executables = ['githook']
  gem.files += Dir['bin/*']
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

