=begin
Copyright (C) 2013 Carl P. Corliss

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
=end

# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$:.unshift(lib) unless $:.include?(lib)
require 'githooks/version'

Gem::Specification.new do |spec|
  spec.name             = "rabbitt-githooks"
  spec.version          = GitHooks::VERSION
  spec.authors          = ["Carl P. Corliss"]
  spec.email            = ["rabbitt@gmail.com"]
  spec.description      = "GitHooker provides a framework for building tests that can be used with git hooks"
  spec.homepage         = "http://github.com/rabbitt/githooks"
  spec.summary          = "framework for building git hooks tests"
  spec.license          = "GPLv2"
  spec.rubygems_version = "2.0.14"

  spec.files            = `git ls-files`.split($/)
  spec.executables      = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files       = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths    = ["lib"]
  spec.extra_rdoc_files = ["README.md", 'LICENSE.txt']

  spec.add_dependency 'colorize', '~> 0.5.8'

  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency 'awesome_print'
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-debugger"
  spec.add_development_dependency "rubocop"
end
