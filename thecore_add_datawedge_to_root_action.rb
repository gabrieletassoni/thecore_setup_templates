# Adding dependecies to gemspec
models_versions = Dir.glob('../*_models/lib/*/version.rb')
if !models_versions.empty? && yes?("Found Models in parent directory, would you like to add them as a dependency", :red)
    models_versions.each do |v|
        model_name = v[/lib\/(.*)\/version/, 1]
        model_version = File.open v { |file| file.find { |line| line =~ /VERSION = '(.*)'$/ } }[/'(.*)'/,1].split('.').first(2).join('.') rescue "1.0"

        inject_into_file "#{name}.gemspec", before: /^end/ do
            "   s.add_dependency '#{model_name}', '~> #{model_version}'\n"
        end
        inject_into_file "lib/#{name}.rb", before: /^module #{Thor::Util.camel_case(name)}$/ do
            "require '#{model_name}'\n"
        end
    end
end
# Getting higher version of the datawedge gem
output = run 'gem search ^thecore_datawedge_websocket_helpers$ -ra', capture: true
versions = (begin
              output.match(/^[\s\t]*thecore_datawedge_websocket_helpers \((.*)\)/)[1].split(', ')
            rescue StandardError
              []
            end)

version = "~> #{begin
                  versions.first.split('.').first(2).join('.')
                rescue StandardError
                  '1.0'
                end}"
inject_into_file "#{name}.gemspec", before: /^end/ do
    "   s.add_dependency 'thecore_datawedge_websocket_helpers', '#{version}'\n"
end
inject_into_file "lib/#{name}.rb", before: /^module #{Thor::Util.camel_case(name)}$/ do
    "require 'thecore_datawedge_websocket_helpers'\n"
end
# Adding code to View
remove_file "app/views/rails_admin/main/#{name.gsub("rails_admin_", "")}.html.haml"
inject_into_file "app/views/rails_admin/main/#{name.gsub("rails_admin_", "")}.html.erb", after: "<%= breadcrumb %>" do
    pivot = '<%= render "barcode_scan_mode_detection"%>\n'
    pivot += '<%= render "datawedge_websocket_input_group" %>\n'
    pivot += '\n'
    pivot += '<div class="row" style="margin-top: 1em">\n'
    pivot += '\t<div id="code-read" class="col-lg-12 collapse"></div>\n'
    pivot += '</div>\n'
    pivot += '\n'
    pivot += '<script>\n'
    pivot += "   var clickedBtn;\n"
    pivot += "   var code;\n"
    pivot += "\n"
    pivot += "   function setAll() {\n"
    pivot += "       // Showing all data\n"
    pivot += "       $('#code-read').show();\n"
    pivot += "   }\n"
    pivot += "\n"
    pivot += "   function resetAll() {\n"
    pivot += "       // Hiding and clearing previous reads\n"
    pivot += "       $('#code-read').empty();\n"
    pivot += "       $('#code-read').hide();\n"
    pivot += "   }\n"
    pivot += "\n"
    pivot += "   $('#send').on('click', function () {\n"
    pivot += "       clickedBtn = $(this);\n"
    pivot += "       code = $('#barcode');\n"
    pivot += "       code.prop('disabled', true);\n"
    pivot += "       clickedBtn.button('loading');\n"
    pivot += "       //Send scanned barcode to controller\n"
    pivot += "       $.get('<%=rails_admin.#{name.gsub("rails_admin_", "")}_path%>', {\n"
    pivot += "           barcode: code.val()\n"
    pivot += "       }, function (data, status) {\n"
    pivot += "           resetAll();\n"
    pivot += "           $('#code-read').append(data.barcode.scanned);\n"
    pivot += "           setAll();\n"
    pivot += "           resetCurrentBtn();\n"
    pivot += "       }).fail(function (errorObj) {\n"
    pivot += "           resetCurrentBtn();\n"
    pivot += "           resetAll();\n"
    pivot += "           openModal('<%=t :error %>', errorObj.responseJSON.error);\n"
    pivot += "       });\n"
    pivot += "   });\n"
    pivot += '</script>\n'
    pivot += '<%= render "datawedge_websocket_input_group_logic" %>\n'
end

# Adding code to controller
inject_into_file "lib/#{name}.rb", after: "if request.xhr?" do
    pivot = "\n"
    pivot += "               if params[:barcode].blank?\n"
    pivot += '                   # Sent an empty barcode: ERROR!\n'
    pivot += '                   message, status = [{ error: "#{I18n.t(:empty_barcode)}" }, 400]\n'
    pivot += '               else\n'
    pivot += '                   # Sent a good barcode, do something with it\n'
    pivot += '                   message, status = [{ barcode: params[:barcode] }, 200]\n'
    pivot += '               end\n'
    pivot += '               # Send back the answer to the caller\n'
    pivot += '               render json: MultiJson.dump(message), status: status\n'
    pivot += "\n"
end