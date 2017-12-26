run "gem install bundler --no-ri --no-rdoc", capture: false
current_gem_user = run "bundle config www.taris.it", capture: true
# Set for the current user (/Users/iltasu/.bundle/config): "bah"
credentials = current_gem_user.match(/^[\s\t]*Set for the current user .*: "(.*)"/)[1] rescue nil

if(credentials.blank? || yes?("Credentials already set, do you want to change them?", :red))
  username = ask "Please provide your username: ", :red
  password = ask "Please provide your password: ", :red
  credentials = "#{username}:#{password}"
  run "bundle config www.taris.it '#{credentials}'"
  run "gem sources --add 'https://#{credentials}@www.taris.it/gems-repo/'"
end

# Versioning on major versions, there is where breakage con occour
# minor versions and patches must be made backward compatible
output = run "gem search ^thecore$ -ra --source https://www.taris.it/gems-repo/", capture: true
gem_dependency = "s.add_dependency 'thecore'"
versions = output.match(/^[\s\t]*thecore \((.*)\)/)[1].split(", ") rescue []
unless versions.empty?
  answer = ask "Which version of thecore do you want to use?", :red, limited_to: versions
  say "You selected #{answer}"
  gem_dependency += ", '~> #{answer.split(".").first(2).join(".")}'"
end
# GEMSPEC
gsub_file "#{@name}.gemspec", 's.add_dependency', '# s.add_dependency'
gsub_file "#{@name}.gemspec", 's.add_development_dependency', '# s.add_development_dependency'

gsub_file "#{@name}.gemspec", 's.homepage', "s.homepage = 'https://www.taris.it' #"
gsub_file "#{@name}.gemspec", 's.summary', "s.summary = 'Thecorized #{@name}' #"
gsub_file "#{@name}.gemspec", 's.description', "s.description = 'Thecorized #{@name} full description.' #"

inject_into_file "#{@name}.gemspec", before: /^end/ do
"  #{gem_dependency}
"
end

inject_into_file "lib/#{@name}/engine.rb", before: /^module #{Thor::Util.camel_case(@name)}$/ do
"require 'thecore'
"
end

# GEMFILE
add_source "https://www.taris.it/gems-repo" do
  gem 'thecore', "~> #{answer.split(".").first(2).join(".") rescue '1.0'}" # , path: '../../thecore_project/thecore'
end

gem 'sqlite3' # Necessario per rails quando faccio girare il tutto da engine

# Run bundle
run "bundle"

# then run thecorize_plugin generator
# rails_command "g thecore:thecorize_plugin #{@name}"
say "Setting the variables", :green
@plugin_path = @destination_stack.first.match(Regexp.new("^.*#{@name}"))[0]
@parent_path = File.expand_path("..", @plugin_path)
@plugin_parent_name = @parent_path.split(File::SEPARATOR).last
@plugin_initializers_dir = File.join(@plugin_path, "config", "initializers")
@plugin_models_dir = File.join(@plugin_path, "app", "models")
@plugin_lib_file = File.join(@plugin_path, "lib", @name, "engine.rb")
Dir.chdir @plugin_models_dir do
  # Getting all the models that are activerecords:
  @model_files = Dir.glob("*.rb").map do |model|
    file = File.join(@plugin_models_dir,model)
    model if is_applicationrecord?(file)
  end.compact
end

def migrations_to_main_app
  say "Checking if it's an engine"
  if is_engine?(@plugin_lib_file) && !has_add_to_migrations_declaration?(@plugin_lib_file)
    say "Adding migration reflection into engine.rb of", :green
    inject_into_file @plugin_lib_file, after: "class Engine < ::Rails::Engine\n" do
"
initializer '#{@name}.add_to_migrations' do |app|
  unless app.root.to_s == root.to_s
    # APPEND TO MAIN APP MIGRATIONS FROM THIS GEM
    config.paths['db/migrate'].expanded.each do |expanded_path|
      app.config.paths['db/migrate'] << expanded_path
    end
  end
end

"
    end
  end
end

def add_require_thecore
  inject_into_file "lib/#{@name}.rb", before: "require \"#{@name}/engine\"" do
"
require 'thecore'
"
  end
end

def add_ability_file
  # do this just the first time
  say "Adding abilities file", :green
  abilities_file_name = "abilities_#{@name}_concern.rb"
  abilities_file_fullpath = File.join(@plugin_initializers_dir, abilities_file_name)
  initializer abilities_file_name do
"
require 'active_support/concern'

module #{@name.classify}AbilitiesConcern
extend ActiveSupport::Concern
included do
def #{@name}_abilities user
  if user
    # if the user is logged in, it can do certain tasks regardless his role
    if user.admin?
      # if the user is an admin, it can do a lot of things, usually
    end

    if user.has_role? :role
      # a specific role, brings specific powers
    end
  end
end
end
end

# include the extension
TheCoreAbilities.send(:include, #{@name.classify}AbilitiesConcern)
"
  end unless File.exists?(abilities_file_fullpath)
end

def add_after_initialize_file
  # do this just the first time
  say "Adding after_initialize file", :green
  after_initialize_file_name = "#{@name}_after_initialize.rb"
  after_initialize_file_fullpath = File.join(@plugin_initializers_dir, after_initialize_file_name)
  initializer after_initialize_file_name do
"
Rails.application.configure do
config.after_initialize do
end
end
"
  end unless File.exists?(after_initialize_file_fullpath)
end

def manage_git
  say "Manage Git", :green
  rails_command "g thecore:add_git #{@name}"
end

def thecoreize_the_models
  rails_command "g thecore:thecorize_models #{@name}"
end

# RUNNING FUNCTIONS
migrations_to_main_app
add_require_thecore
add_ability_file
add_after_initialize_file
manage_git
thecoreize_the_models

# PRIVATE FUNCTIONS
def ask_question_multiple_choice models, question = "Choose among one of these, please."
  return [] if models.empty?
  # raccolgo tutte le risposte che non siano cancel
  # e ritorno l'array
  return_array = []
  while (answer ||= "") != "cancel"
    remaining_models = (models-return_array)
    break if remaining_models.empty?
    answer = ask question, :red, limited_to: remaining_models.push("cancel").uniq
    break if answer == "cancel"
    return_array.push answer
  end
  return return_array
end

def is_has_many_through? file, assoc, through
  (File.readlines(file).grep(/^[ \t]*has_many[ \t]+:#{assoc},[ \t]+through:[ \t]+:#{through}.*/).size > 0) rescue false
end

def has_polymorphic_has_many? file, polymorphic_name
  (File.readlines(file).grep(/^[ \t]*has_many.+as: :#{polymorphic_name}.*/).size > 0) rescue false
end

def is_activerecord? file
  (File.readlines(file).grep(/^class [A-Za-z0-9]+ < ActiveRecord::Base/).size > 0) rescue false
end

def is_applicationrecord? file
  (File.readlines(file).grep(/^class [A-Za-z0-9]+ < ApplicationRecord/).size > 0) rescue false
end

def has_rails_admin_declaration? file
  (File.readlines(file).grep(/^[ \t]*rails_admin do/).size > 0) rescue false
end

def is_engine? file
  (File.readlines(file).grep(/^[ \t]*class Engine < ::Rails::Engine/).size > 0) rescue false
end

def has_add_to_migrations_declaration? file
  (File.readlines(file).grep(/^[ \t]*initializer '[a-zA-Z0-9]+\.add_to_migrations' do \|app\|/).size > 0) rescue false
end

def has_has_many_association? file, assoc
  reg_def = "^[ \\t]+has_many[ \\t]+:#{assoc}"
  (File.readlines(file).grep(Regexp.new(reg_def)).size > 0) rescue false
end