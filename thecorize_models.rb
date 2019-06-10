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
    (File.readlines(file).grep(/^[ \t]*RailsAdmin.config do/).size > 0) rescue false
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

# Dir.chdir 'app/models' do
# Getting all the models that are activerecords:
Dir.chdir('app/models') do
    @model_files = Dir.glob('*.rb').map do |model|
        "app/models/#{model}" if is_applicationrecord?(model) || is_activerecord?(model)
    end.compact 
end
# end

say "Found these models: #{@model_files.join("; ")}"

say "Replace ActiveRecord::Base with ApplicationRecord", :green
say "Add rails_admin declaration only in files which are ActiveRecords and don't already have that declaration", :green
say "Completing Belongs To Associations", :green
# For each model in this gem
@model_files.each do |entry|
    # It must be a class and don't have rails_admin declaration
    say "Working on: #{entry}"
    gsub_file entry, "ActiveRecord::Base", "ApplicationRecord"
    # Rails admin
    inject_into_file entry, before: /^end/ do
        pivot = "\n"
        pivot += "RailsAdmin.config do |config|\n"
        pivot += "   config.model self.name.underscore.capitalize.classify do\n"
        pivot += "       navigation_label I18n.t('admin.settings.label')\n"
        pivot += "       navigation_icon 'fa fa-file'\n"
        pivot += "    end\n"
        pivot += "end\n"
        pivot += "\n"
        pivot
    end unless has_rails_admin_declaration entry
    # Belongs to
    gsub_file entry, /^(?!.*inverse_of.*)^[ \t]*belongs_to.*$/ do |match|
        match << ", inverse_of: :#{entry.split(".").first.pluralize}"
    end
end

say "Add Has Many Through Associations", :green
# I'ts just an approximation, but for now it could work
@model_files.each do |model|
    association_model = model.split(".").first
    file = File.join(model)
    # It must be an activerecord model class
    model_with_belongs_to = File.readlines(file).grep(/^[ \t]*belongs_to :.*$/)
    if model_with_belongs_to.size == 2
        if yes?("Is #{association_model} an association model for a has_many through relation?", :red)
            # getting both the belongs_to models, find their model files, and add the through to each other
            left_side = model_with_belongs_to.first[/:(.*?),/,1]
            right_side = model_with_belongs_to.last[/:(.*?),/,1]
            # This side of the through
            inject_into_file File.join("app/models", "#{left_side}.rb"), after: " < ApplicationRecord\n" do
                #has_many :rooms, through: :chosen_rooms, inverse_of: :chosen_decks
                "    has_many :#{right_side.pluralize}, through: :#{association_model.pluralize}, inverse_of: :#{left_side.pluralize}"
            end
            # Other side of the through
            inject_into_file File.join("app/models", "#{right_side}.rb"), after: " < ApplicationRecord\n" do
                #has_many :rooms, through: :chosen_rooms, inverse_of: :chosen_decks
                "    has_many :#{left_side.pluralize}, through: :#{association_model.pluralize}, inverse_of: :#{right_side.pluralize}"
            end
        end
    end
end

say "Add Has Many Associations", :green
# For each model in this gem
@model_files.each do |entry|
    file = File.join(entry)
    # It must be an activerecord model class
    if is_applicationrecord?(file)
        # say "Looking for belongs_to in #{entry} and adding the relevant has_manies", :green

        # Polymorphic must be managed manually
        File.readlines(file).grep(/^(?!.*polymorphic.*)^[ \t]*belongs_to :(.*),.+/).each do |a|
            target_association = a[/:(.*?),/,1]
            # look if the file identified by association .rb exists
            associated_file = File.join("app/models","#{target_association}.rb")
            starting_model = entry.split(".").first.pluralize
            # say "Found belongs_to association: #{target_association} for the model: #{starting_model}", :green
            # say "- Looking for model file: #{associated_file}", :green
            if File.exists?(associated_file)
                # say "The file in which to add has_many, exists and the has_many does not! #{associated_file}", :green
                # if true, check that the association is non existent and add the association to that file
                inject_into_file associated_file, after: " < ApplicationRecord\n" do
                    "\n\t\thas_many :#{starting_model}, inverse_of: :#{target_association}, dependent: :destroy\n"
                end unless has_has_many_association?(associated_file, starting_model)
            else
                # otherwise (the file does not exist) check if the initializer for concerns exists,
                # For each model in this gem
                initializer_name = "associations_#{name}_#{target_association}_concern.rb"
                initializer initializer_name do
                    pivot = "require 'active_support/concern'\n"
                    pivot += "\n"
                    pivot += "module #{target_association.classify}AssociationsConcern\n"
                    pivot += "   extend ActiveSupport::Concern\n"
                    pivot += "   included do\n"
                    pivot += "   end\n"
                    pivot += "end\n"
                    pivot += "\n"
                    pivot += "# include the extension\n"
                    pivot += "# #{target_association.classify}.send(:include, #{target_association.classify}AssociationsConcern)\n"
                    pivot += "\n"
                end unless File.exists?(File.join("config/initializers", initializer_name))
    
                # AGGIUNGO L'INCLUDE
                say "Adding after_initialize file", :green
                after_initialize_file_name = "after_initialize_for_#{@name}.rb"
                after_initialize_file_fullpath = File.join("config/initializers", after_initialize_file_name)
                initializer after_initialize_file_name do
                    "Rails.application.configure do\n   config.after_initialize do\n    end\nend"
                end unless File.exists?(after_initialize_file_fullpath)
                inject_into_file after_initialize_file_fullpath, after: "config.after_initialize do\n" do
                    "\n\t\t#{target_association.classify}.send(:include, #{target_association.classify}AssociationsConcern)\n"
                end
    
                # then add to it the has_many declaration
                # TODO: only if it doesn't already exists
                inject_into_file File.join(@plugin_initializers_dir, initializer_name), after: "included do\n" do
                    "\n     has_many :#{starting_model}, inverse_of: :#{target_association}, dependent: :destroy\n"
                end
            end
        end
    end
end

say "Detect polymorphic Associations", :green
# For each model in this gem
# say "MODEL FILES: #{@model_files.inspect} "
@model_files.each do |model|
    file = File.join(model)
    # It must be an activerecord model class
    # belongs_to :rowable, polymorphic: true, inverse_of: :rows
    polymorphics = File.readlines(file).grep(/^[ \t]*belongs_to :.*polymorphic.*/)
    polymorphics.each do |polymorphic_belongs_to|
        polymorphic_target_association = polymorphic_belongs_to[/:(.*?),/,1]
        # Just keeping the models that are not this model, and
        answers = ask_question_multiple_choice @model_files.reject {|m| m == model || has_polymorphic_has_many?(File.join(@plugin_models_dir,m), polymorphic_target_association)}, "Where do you want to add the polymorphic has_many called #{polymorphic_target_association} found in #{model}?"
        answers.each do |answer|
            # Add the polymorphic has_name declaration
            inject_into_file File.join("app/models", answer), after: " < ApplicationRecord\n" do
                "   has_many :#{model.split(".").first.pluralize}, as: :#{polymorphic_target_association}, inverse_of: :#{answer.split(".").first.singularize}, dependent: :destroy"
            end
        end
    end
end
