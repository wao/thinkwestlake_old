require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
    t.pattern = "test/**/*_test.rb"
end

task 'console' do
    $: << 'lib'
    require 'thinwestlake/maven/pom'
    include ThinWestLake::Maven
    require 'irb'
    ARGV.clear
    IRB.start
end
