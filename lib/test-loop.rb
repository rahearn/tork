require 'rake' # for String#pathmap

# absorb test execution overhead into master process
overhead_file_glob = '{test,spec}/*_helper.rb'
$LOAD_PATH.unshift 'lib' # for non-Rails applications

Dir[overhead_file_glob].each do |file|
  $LOAD_PATH.unshift file.pathmap('%d')
  require file.pathmap('%n')
end

# continuously watch for and test changed code
started_at = last_ran_at = Time.now

trap :QUIT do
  puts 'Reabsorbing overhead...'
  started_at = Time.at(0)
end

trap :TSTP do
  puts 'Testing everything...'
  last_ran_at = Time.at(0)
end

puts 'Ready for testing...'
loop do
  # figure out what test files need to be run
  test_files = {
    '{test,spec}/**/*_{test,spec}.rb' => '%p',
    '{lib,app}/**/*.rb' => '{test,spec}/**/%n_{test,spec}%x',
  }.
  map do |source_file_glob, test_file_pathmap|
    Dir[source_file_glob].
    select {|file| File.mtime(file) > last_ran_at }.
    map {|path| Dir[path.pathmap(test_file_pathmap)] }
  end.flatten.uniq

  # fork worker process to run the test files
  unless test_files.empty?
    last_ran_at = Time.now
    fork { test_files.each {|file| load file } }
    Process.wait
  end

  # reabsorb test execution overhead as necessary
  if Dir[overhead_file_glob].any? {|file| File.mtime(file) > started_at }
    exec 'ruby', __FILE__, *ARGV
  end

  sleep 1
end
