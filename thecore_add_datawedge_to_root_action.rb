# Adding dependecies to gemspec
models_versions = Dir.glob('../*_models/lib/*/version.rb')
if !models_versions.empty? && yes?("Found Models in parent directory, would you like to add them as a dependency", :red)
    models_versions.each do |v|
        model_name = v[/lib\/(.*)\/version/, 1]
        model_version = File.open v { |file| file.find { |line| line =~ /VERSION = '(.*)'$/ } }[/'(.*)'/,1].split('.').first(2).join('.') rescue "1.0"

        inject_into_file "#{name}.gemspec", before: /^end/ do
            "  spec.add_dependency '#{model_name}', '~> #{model_version}'\n"
        end
        inject_into_file "lib/#{name}.rb", before: /^module #{Thor::Util.camel_case(name)}$/ do
            "require '#{model_name}'\n"
        end
    end
end
# Getting higher version of the datawedge gem
output = run 'gem search ^thecore_dataentry_commons$ -ra', capture: true
versions = (begin
              output.match(/^[\s\t]*thecore_dataentry_commons \((.*)\)/)[1].split(', ')
            rescue StandardError
              []
            end)

version = "~> #{begin
                  versions.first.split('.').first(2).join('.')
                rescue StandardError
                  '1.0'
                end}"
inject_into_file "#{name}.gemspec", before: /^end/ do
    "   spec.add_dependency 'thecore_dataentry_commons', '#{version}'\n"
end
inject_into_file "lib/#{name}.rb", before: /^module #{Thor::Util.camel_case(name)}$/ do
    "require 'thecore_dataentry_commons'\n"
end
# Adding code to View
remove_file "app/views/rails_admin/main/#{name.gsub("rails_admin_", "")}.html.haml"
inject_into_file "app/views/rails_admin/main/#{name.gsub("rails_admin_", "")}.html.erb", after: "<%= breadcrumb %>" do
'
<!-- 
Source code of this partial can be found here:
https://raw.githubusercontent.com/gabrieletassoni/thecore_dataentry_commons/master/app/views/higher_level/_barcode_simple_scan.html.erb

There you can find several functions you can override in order to customize behaviour 
and computations to suit your application, the most notable ones are:

barcodeScannedSuccess(data, status)
barcodeScannedThen(appended)
barcodeScannedFailure(errorObj)

Look for the comment "// These functions can be overridden in the containing file"
in order to find all of them.
//-->
<%= render "higher_level/barcode_simple_scan"%>
'
end

# Adding code to controller
inject_into_file "lib/#{name}.rb", after: "if request.xhr?" do
    pivot = "\n"
    pivot += "                   if params[:barcode].blank?\n"
    pivot += '                        # Sent an empty barcode: ERROR!'
    pivot += "\n"
    pivot += '                        message, status = [{ error: I18n.t(:barcode_cannot_be_empty) }, 400]'
    pivot += "\n"
    pivot += '                   else'
    pivot += "\n"
    pivot += '                        # Sent a good barcode, do something with it'
    pivot += "\n"
    pivot += '                        message, status = [{ info: I18n.t(:barcode_found), barcode: params[:barcode] }, 200]'
    pivot += "\n"
    pivot += '                        message[:parameters] = params[:parameters] unless params[:parameters].blank?'
    pivot += "\n"
    pivot += '                   end'
    pivot += "\n"
    pivot += '                   # Send back the answer to the caller'
    pivot += "\n"
    pivot += '                   render json: MultiJson.dump(message), status: status'
    pivot += "\n"
end
