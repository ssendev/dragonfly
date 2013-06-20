require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'dragonfly'
require 'fileutils'
require 'tempfile'
require 'pry'
require 'webmock/rspec'

# Requires supporting files with custom matchers and macros, etc,
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

SAMPLES_DIR = Pathname.new(File.expand_path(File.dirname(__FILE__) + '/../samples')) unless defined?(SAMPLES_DIR)

RSpec.configure do |c|
  c.include ModelHelpers
end

def todo
  raise "TODO"
end

require 'logger'
LOG_FILE = 'tmp/test.log' unless defined?(LOG_FILE)
FileUtils.rm_rf(LOG_FILE)

RSpec.configure do |c|
  c.after(:each) do
    Dragonfly::App.destroy_apps
  end
end

def mock_app(extra_stubs={})
  mock('app', {
    :datastore => mock('datastore', :store => 'some_uid', :retrieve => ["SOME_DATA", {}], :destroy => nil),
    :processor => mock('processor', :process => "SOME_PROCESSED_DATA"),
    :analyser => mock('analyser', :analyse => "some_result", :analysis_methods => Module.new),
    :generator => mock('generator', :generate => "SOME_GENERATED_DATA"),
    :log => Logger.new(LOG_FILE),
    :cache_duration => 10000,
  }.merge(extra_stubs)
  )
end

def test_app(name=:default)
  time = Time.now
  app = Dragonfly::App[name]
  app.datastore = Dragonfly::DataStorage::MemoryDataStore.new
  app.log = Logger.new(LOG_FILE)
  app
end

def test_imagemagick_app
  test_app.configure do
    add_generator :convert, Dragonfly::ImageMagick::Generators::Convert.new
    add_processor :convert, Dragonfly::ImageMagick::Processors::Convert.new
    add_analyser :identify_basic, Dragonfly::ImageMagick::Analysers::IdentifyBasic.new
  end
end

def suppressing_stderr
  original_stderr = $stderr.dup
  tempfile = Tempfile.new('stderr')
  $stderr.reopen(tempfile) rescue
  yield
ensure
  tempfile.close!
  $stderr.reopen(original_stderr)
end
