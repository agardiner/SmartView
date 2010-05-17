require 'rubygems'
require 'rake/gempackagetask'
load 'smartview.gemspec'

namespace :gem do
    Rake::GemPackageTask.new(GEMSPEC) do |pkg|
        pkg.need_tar = false
    end
end
