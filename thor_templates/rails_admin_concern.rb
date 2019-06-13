module ##ConcernName##
    extend ActiveSupport::Concern
    included do
        # Here You can define the RailsAdmin DSL
        rails_admin do
            navigation_label I18n.t('admin.settings.label')
            navigation_icon 'fa fa-file'
        end
    end
end
