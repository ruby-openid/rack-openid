require "bundler/gem_tasks"

require "rake/testtask"

require "require_bench" if ENV.fetch("REQUIRE_BENCH", "false").casecmp?("true")

desc "Run tests"
Rake::TestTask.new("test") do |t|
  t.verbose = false
end

begin
  require "rubocop/lts"
  Rubocop::Lts.install_tasks
rescue LoadError
  task(:rubocop_gradual) do
    warn("RuboCop (Gradual) is disabled")
  end
end

begin
  require "ostruct" # until https://github.com/zverok/yard-junk/pull/42 is merged!
  require "yard-junk/rake"

  YardJunk::Rake.define_task
rescue LoadError
  task("yard:junk") do
    warn("yard:junk is disabled")
  end
end

begin
  require "yard"

  YARD::Rake::YardocTask.new(:yard)
rescue LoadError
  task(:yard) do
    warn("yard is disabled")
  end
end

task default: %i[test rubocop_gradual:autocorrect yard yard:junk]
