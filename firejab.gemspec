# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "firejab/version"

Gem::Specification.new do |s|
  s.name        = "firejab"
  s.version     = Firejab::VERSION
  s.authors     = ["Damon P. Cortesi"]
  s.email       = ["d.lifehacker@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Jabber interface for Campfire}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "firejab"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]


  s.add_dependency "twitter-stream",            "~> 0.1.14"
  s.add_dependency "scashin133-xmpp4r-simple",  "~> 0.8.9"    # 1.9.x compat
  s.add_dependency "yajl-ruby",                 "~> 0.8.2"
  s.add_dependency "typhoeus",                  "~> 0.2.4"
end
