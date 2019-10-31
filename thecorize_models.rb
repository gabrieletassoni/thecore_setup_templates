def ask_question_multiple_choice models, question = "Choose among one of these, please."
    return [] if models.empty?
    # raccolgo tutte le risposte che non siano cancel
    # e ritorno l'array
    return_array = []
    while (answer ||= "") != "cancel"
      remaining_models = (models-return_array)
      break if remaining_models.empty?
      answer = ask(question, :green, :bold, limited_to: remaining_models.push("cancel").uniq)
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

loop do
    model_declaration = ask("Please enter a model declaration or NONE if you don't need new models:\n", :green, :bold)
    break if model_declaration.upcase == "NONE"
    generate(:model, model_declaration)
end

puts Dir.pwd
# Dir.chdir 'app/models' do
# Getting all the models that are activerecords:
inside("#{Dir.pwd}/app/models") do
    @model_files = Dir.glob('*.rb').map do |model|
        "app/models/#{model}" if is_applicationrecord?(model) || is_activerecord?(model)
    end.compact 
end
# end

say "Found these models: #{@model_files.join("; ")}"

say "Replace ActiveRecord::Base with ApplicationRecord", :green
say "Add rails_admin declaration only in files which are ActiveRecords and don't already have that declaration", :green

say "Thecorize the Model and completing Belongs To Associations", :green
# For each model in this gem
inside(Dir.pwd) do
    @model_files.each do |entry|
        filename = entry.split("/").last
        m = entry.split(".").first.split("/").last.camelize
        # Download this entry's template for api and railsadmin
        # API
        get "https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/thor_templates/model_api_concern.tt", "app/models/concerns/api/#{filename}" unless File.exists?("app/models/concerns/api/#{filename}")
        get "https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/thor_templates/model_rails_admin_concern.tt", "app/models/concerns/rails_admin/#{filename}" unless File.exists?("app/models/concerns/rails_admin/#{filename}")
        # Replace in the generated file the templates
        gsub_file "app/models/concerns/api/#{filename}", "<%= @model_name %>", m
        gsub_file "app/models/concerns/rails_admin/#{filename}", "<%= @model_name %>", m

        # It must be a class and don't have rails_admin declaration
        say "Working on: #{entry}"
        gsub_file entry, "ActiveRecord::Base", "ApplicationRecord"
        # Associations
        inject_into_file entry, after: " < ApplicationRecord\n" do
            "\t# Associations\n"
        end

        # Validations
        inject_into_file entry, after: " < ApplicationRecord\n" do
            "\t# Validations\n"
        end

        # Concerns
        inject_into_file entry, after: " < ApplicationRecord\n" do
            "\t# Concerns\n\tinclude Api::#{m}\n\tinclude RailsAdmin::#{m}\n"
        end

        # Belongs to
        gsub_file entry, /^(?!.*inverse_of.*)^[ \t]*belongs_to.*$/ do |match|
            match << ", inverse_of: :#{entry.split(".").first.split("/").last.pluralize}"
        end
    end
end

def add_has_many_to_model_or_concern name, associated_model, this_model, through_model = nil
    # In the end I need to create something like:
    # THROUGH VERSION:
    # class this_model < ApplicationRecord
    #     has_many associated_model.pluralize, inverse_of: this_model.singularize, dependent: :destroy
    #     has_many associated_model.pluralize, through: through_model.pluralize, inverse_of: this_model.pluralize
    # end
    # SIMPLE VERSION:
    # class this_model < ApplicationRecord
    #     has_many associated_model.pluralize, inverse_of: this_model.singularize, dependent: :destroy
    # end
    associated_file = File.join("app", "models", "#{this_model.singularize}.rb")
    say "Looking if association model exists: #{associated_file}"
    if File.exists?(associated_file)
        # say "The file in which to add has_many, exists and the has_many does not! #{associated_file}", :green
        # if true, check that the association is non existent and add the association to that file
        inject_into_file associated_file, after: "# Associations\n" do
            pivot = "\thas_many :#{associated_model.pluralize}, inverse_of: :#{this_model.singularize}, dependent: :destroy\n" if through_model.blank?
            pivot = "\thas_many :#{associated_model.pluralize}, through: :#{through_model.pluralize}, inverse_of: :#{this_model.pluralize}\n" unless through_model.blank?
            pivot
        end unless has_has_many_association?(associated_file, associated_model.pluralize)
    else
        # otherwise (the file does not exist) check if the initializer for concerns exists,
        # For each model in this gem
        initializer_name = "associations_#{name}_#{this_model.singularize}_concern.rb"
        initializer initializer_name do
            pivot = "require 'active_support/concern'\n"
            pivot += "\n"
            pivot += "module #{this_model.singularize.classify}AssociationsConcern\n"
            pivot += "    extend ActiveSupport::Concern\n"
            pivot += "    included do\n"
            pivot += "    end\n"
            pivot += "end\n"
            pivot += "\n"
            pivot += "# include the extension\n"
            pivot += "# #{this_model.singularize.classify}.send(:include, #{this_model.singularize.classify}AssociationsConcern)\n"
            pivot += "\n"
            pivot
        end unless File.exists?(File.join("config/initializers", initializer_name))

        # AGGIUNGO L'INCLUDE
        say "Adding after_initialize file"
        after_initialize_file_name = "after_initialize_for_#{name}.rb"
        after_initialize_file_fullpath = File.join("config/initializers", after_initialize_file_name)
        initializer after_initialize_file_name do
            "Rails.application.configure do\n\tconfig.after_initialize do\n\tend\nend"
        end unless File.exists?(after_initialize_file_fullpath)

        inject_into_file after_initialize_file_fullpath, after: "config.after_initialize do\n" do
            "\t#{this_model.singularize.classify}.send(:include, #{this_model.singularize.classify}AssociationsConcern)\n"
        end

        # then add to it the has_many declaration
        # TODO: only if it doesn't already exists
        inject_into_file File.join("config/initializers", initializer_name), after: "included do\n" do
            pivot = "\thas_many :#{associated_model.pluralize}, inverse_of: :#{this_model.singularize}, dependent: :destroy\n" if through_model.blank?
            pivot = "\thas_many :#{associated_model.pluralize}, through: :#{through_model.pluralize}, inverse_of: :#{this_model.pluralize}\n" unless through_model.blank?
            pivot
        end if File.exists?(File.join("config/initializers", initializer_name))
    end
end

say "Add Has Many Through Associations", :green
# I'ts just an approximation, but for now it could work
inside(Dir.pwd) do
    @model_files.each do |model|
        association_model = model.split(".").first.split("/").last
        file = File.join(model)
        # It must be an activerecord model class
        model_with_belongs_to = File.readlines(file).grep(/^[ \t]*belongs_to :.*$/)
        if model_with_belongs_to.size == 2
            if yes?("Is #{association_model} an association model for a has_many through relation?", :red)
                # getting both the belongs_to models, find their model files, and add the through to each other
                left_side = model_with_belongs_to.first[/:(.*?),/,1]
                right_side = model_with_belongs_to.last[/:(.*?),/,1]
                # This side of the through
                add_has_many_to_model_or_concern name, right_side, left_side, association_model
                add_has_many_to_model_or_concern name, left_side, right_side, association_model
            end
        end
    end
end

say "Add Has Many Associations", :green
# For each model in this gem
inside(Dir.pwd) do
    @model_files.each do |entry|
        file = File.join(entry)
        say "Entering #{file}"
        # It must be an activerecord model class
        if is_applicationrecord?(file)
            say "- It's an applicationrecord"
            # say "Looking for belongs_to in #{entry} and adding the relevant has_manies", :green

            # Polymorphic must be managed manually
            File.readlines(file).grep(/^(?!.*polymorphic.*)^[ \t]*belongs_to :(.*),.+/).each do |a|
                this_model = a[/:(.*?),/,1]
                # look if the file identified by association .rb exists
                # associated_file = File.join("app/models","#{target_association}.rb")
                associated_model = entry.split(".").first.split("/").last.pluralize
                # say "Found belongs_to association: #{target_association} for the model: #{starting_model}", :green
                # say "- Looking for model file: #{associated_file}", :green
                # add_has_many_to_model_or_concern name, associated_model, this_model
                add_has_many_to_model_or_concern name, associated_model, this_model
            end
        end
    end
end

say "Detect polymorphic Associations", :green
# For each model in this gem
# say "MODEL FILES: #{@model_files.inspect} "
inside(Dir.pwd) do
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
                inject_into_file File.join("app/models", answer), after: "# Associations\n" do
                    "\thas_many :#{model.split(".").first.split("/").last.pluralize}, as: :#{polymorphic_target_association}, inverse_of: :#{answer.split(".").first.split("/").last.singularize}, dependent: :destroy"
                end if File.exists?(File.join("app/models", answer))
            end
        end
    end
end

say "Detect orphaned Has Many", :green
inside(Dir.pwd) do
    @model_files.each do |model|
        file = File.join(model)
        # It must be an activerecord model class
        # belongs_to :rowable, polymorphic: true, inverse_of: :rows
        manies = File.readlines(file).grep(/^[ \t]*has_many.*/)
        manies.each do |has_many|
            target_association = has_many[/:(.*?),/,1]
            associated_file = File.join("app", "models", "#{target_association.singularize}.rb")
            say "Looking if association model exists: #{associated_file}"
            if !File.exists?(associated_file)
                # This is the case where the model file doesn't exist in the current engine, maybe it's in another one
                # Which this engine depends on, let's create the concern
                # otherwise (the file does not exist) check if the initializer for concerns exists,
                # For each model in this gem
                initializer_name = "associations_#{model.split(".").first.split("/").last}_#{target_association.singularize}_concern.rb"
                initializer initializer_name do
                    pivot = "require 'active_support/concern'\n"
                    pivot += "\n"
                    pivot += "module #{target_association.singularize.classify}AssociationsConcern\n"
                    pivot += "    extend ActiveSupport::Concern\n"
                    pivot += "    included do\n"
                    pivot += "    end\n"
                    pivot += "end\n"
                    pivot += "\n"
                    pivot += "# include the extension\n"
                    pivot += "# #{target_association.singularize.classify}.send(:include, #{target_association.singularize.classify}AssociationsConcern)\n"
                    pivot += "\n"
                    pivot
                end unless File.exists?(File.join("config/initializers", initializer_name))

                # AGGIUNGO L'INCLUDE
                say "Adding after_initialize file"
                after_initialize_file_name = "after_initialize_for_#{model.split(".").first.split("/").last}.rb"
                after_initialize_file_fullpath = File.join("config/initializers", after_initialize_file_name)
                initializer after_initialize_file_name do
                    "Rails.application.configure do\n\tconfig.after_initialize do\n\tend\nend"
                end unless File.exists?(after_initialize_file_fullpath)

                inject_into_file after_initialize_file_fullpath, after: "config.after_initialize do\n" do
                    "\t#{target_association.singularize.classify}.send(:include, #{target_association.singularize.classify}AssociationsConcern)\n"
                end

                # then add to it the has_many declaration
                # TODO: only if it doesn't already exists
                inject_into_file File.join("config/initializers", initializer_name), after: "included do\n" do
                    pivot = "\tbelongs_to :#{model.split(".").first.split("/").last.singularize}, inverse_of: :#{target_association.pluralize}\n"
                    pivot
                end if File.exists?(File.join("config/initializers", initializer_name))
            end
        end
    end
end

# rails_command "db:migrate"
