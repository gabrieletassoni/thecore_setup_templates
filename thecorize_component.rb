unless File.exists? "config/locales/#{name}.en.yml" # Keep the already existing one
    create_file "config/locales/#{name}.en.yml", "--- \nen:\n  admin:\n    actions:\n      #{name}:\n        menu: #{name.titleize}\n        breadcrumb: #{name.titleize}\n        title: #{name.titleize}"
end
unless File.exists? "config/locales/#{name}.it.yml" # Keep the already existing one
    FileUtils.cp "config/locales/#{name}.en.yml", "config/locales/#{name}.it.yml" 
    gsub_file "config/locales/#{name}.it.yml" , /^en:&/, 'it:'
end
# Make the migrations in this engine be directly available to main app
inject_into_file "lib/#{name}/engine.rb", after: "class Engine < ::Rails::Engine\n" do
"
    initializer '#{name}.add_to_migrations' do |app|
      unless app.root.to_s == root.to_s
        # APPEND TO MAIN APP MIGRATIONS FROM THIS GEM
        config.paths['db/migrate'].expanded.each do |expanded_path|
          app.config.paths['db/migrate'] << expanded_path
        end
      end
    end

"
end

# add an initializer for abilities (authorization)
initializer "abilities_#{name}_concern.rb" do
"
require 'active_support/concern'

module #{name.classify}AbilitiesConcern
    extend ActiveSupport::Concern
    included do
    def #{name}_abilities user
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
TheCoreAbilities.send(:include, #{name.classify}AbilitiesConcern)
"
end

initializer "after_initialize_for_#{name}.rb" do
"
Rails.application.configure do
    config.after_initialize do
    end
end
"
end

# then run thecorize_models
apply "https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/thecorize_models.rb"
