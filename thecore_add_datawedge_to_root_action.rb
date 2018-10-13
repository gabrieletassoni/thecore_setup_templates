# Adding dependecies to gemspec
models_versions = Dir.glob('../*_models/lib/*/version.rb')
if !models_versions.empty? && yes?("Found Models in parent directory, would you like to add them as a dependency", :red)
    models_versions.each do |v|
        model_name = v[/lib\/(.*)\/version/, 1]
        model_version = File.open v { |file| file.find { |line| line =~ /VERSION = '(.*)'$/ } }[/'(.*)'/,1].split('.').first(2).join('.') rescue "1.0"

        inject_into_file "#{name}.gemspec", before: /^end/ do
            "   s.add_dependency '#{model_name}', '~> #{model_version}'\n"
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
inject_into_file "app/views/rails_admin_main/#{name.gsub("rails_admin_", "")}.html.erb", after: "<%= breadcrumb %>" do
    '<%= render "barcode_scan_mode_detection"%>'
    '<%= render "datawedge_websocket_input_group" %>'
    ''
    '<div class="row" style="margin-top: 1em">'
    '\t<div id="code-read" class="col-lg-12 collapse"></div>'
    '</div>'
    ''
    '<script>'
    "   var clickedBtn;"
    "   var code;"
    ""
    "   function setAll() {"
    "       // Showing all data"
    "       $('#code-read').show();"
    "   }"
    ""
    "   function resetAll() {"
    "       // Hiding and clearing previous reads"
    "       $('#code-read').empty();"
    "       $('#code-read').hide();"
    "   }"
    ""
    "   $('#send').on('click', function () {"
    "       clickedBtn = $(this);"
    "       code = $('#barcode');"
    "       code.prop('disabled', true);"
    "       clickedBtn.button('loading');"
    "       //Send scanned barcode to controller"
    "       $.get('<%=rails_admin.#{name.gsub("rails_admin_", "")}_path%>', {"
    "           barcode: code.val()"
    "       }, function (data, status) {"
    "           resetAll();"
    "           $('#code-read').append(data.barcode.scanned);"
    "           setAll();"
    "           resetCurrentBtn();"
    "       }).fail(function (errorObj) {"
    "           resetCurrentBtn();"
    "           resetAll();"
    "           openModal('<%=t :error %>', errorObj.responseJSON.error);"
    "       });"
    "   });"
    '</script>'
    '<%= render "datawedge_websocket_input_group_logic" %>'
end

# Adding code to controller
inject_into_file "lib/#{name}.rb", after: "if request.xhr?" do
    ""
    "               if params[:barcode].blank?"
    '                   # Sent an empty barcode: ERROR!'
    '                   message, status = [{ error: "#{I18n.t(:empty_barcode)}" }, 400]'
    '               else'
    '                   # Sent a good barcode, do something with it'
    '                   message, status = [{ barcode: params[:barcode] }, 200]'
    '               end'
    '               # Send back the answer to the caller'
    '               render json: MultiJson.dump(message), status: status'
    ""
end