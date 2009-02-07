$:.unshift(File.dirname(__FILE__) + '/../lib/')

Spec::Runner.configure do |config|
  config.mock_with :mocha
end

def load_rails_environment
  dir = File.dirname(__FILE__)
  ENV["RAILS_ENV"] ||= "test"
  require "#{dir}/../../../../config/environment"
  require "#{dir}/../init.rb"
end

def setup_rails_database
  dir = File.dirname(__FILE__)

  db = YAML::load(IO.read("#{dir}/resources/config/database.yml"))
  ActiveRecord::Base.configurations = {'test' => db[ENV['DB'] || 'sqlite3']}
  ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'])
  ActiveRecord::Migration.verbose = false
  load "#{dir}/resources/schema"
end

def drop_rails_database
  database = ActiveRecord::Base.configurations['test'][:dbfile]
  ActiveRecord::Base.connection.disconnect!
  #  puts "succes? #{File.delete database}"
end

# For debugging generated specs - when running specs with the HTML-runner, this formats response.body for easy inspection
def print_response *values
  values = [response.body] if values.blank?
  values.each do |value|
    puts "<pre>" + ERB::Util.html_escape(value) + "</pre>"
  end
end
