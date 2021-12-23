require "rake/testtask"

task default: "test"

Rake::TestTask.new do |t|
  t.test_files = FileList['test/test_helper.rb', 'test/**/*_test.rb']
end
