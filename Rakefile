require "rake/clean"
require "rubygems/package_task"

require_relative "lib/tfmt"	# TFmt::VERSION

task :default => :gem

file "bin/tfmt" => [ "bin/tfmt.rb", "lib/tfmt.rb" ] do
  cp "bin/tfmt.rb", "bin/tfmt"
  chmod 0755, "bin/tfmt"
end

task :gem => [ "bin/tfmt" ]
spec = Gem::Specification.new { |s|
  s.name = "tfmt"
  s.version = TFmt::VERSION
  s.author = "NOZAWA Hiromasa"
  s.summary = "very straight-forward text markup"
  s.license = "BSD-2-Clause"
  # s.homepage = "https://github.com/noz/tfmt"
  s.required_ruby_version = "~> 3.0"
  s.add_runtime_dependency "trad-getopt", "~> 2.0"
  # s.add_runtime_dependency "rmagick", "~> 2.16"
  # s.add_runtime_dependency "streamio-ffmpeg", "~> 3.0"
  s.files = FileList[
    # "ChangeLog",
    # "LICENSE",
    "Rakefile",
    #
    "bin/tfmt.rb",
    "bin/tfmt",
    "lib/tfmt.rb",
    "lib/style.css",
  ]
  s.bindir = "bin"
  s.executables = [ "tfmt" ]
  s.require_path = "lib"
}
Gem::PackageTask.new(spec) {|pkg|
  pkg.need_tar_gz = true
  pkg.need_tar_bz2 = true
  pkg.need_zip = true
}

CLOBBER << "bin/tfmt"
