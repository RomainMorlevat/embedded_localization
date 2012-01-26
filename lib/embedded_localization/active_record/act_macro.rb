module EmbeddedLocalization
  module ActiveRecord
    module ActMacro
      def translates(*attr_names)
        return if translates?  # cludge to make sure we don't set this up twice..

        options = attr_names.extract_options!
        # options[:fallback] => true or false

        class_attribute :translated_attribute_names, :translation_options
        self.translated_attribute_names = attr_names.map(&:to_sym).sort.uniq
        self.translation_options        = options

        include InstanceMethods
        extend  ClassMethods

        # if ActiveRecord::Base is in the parent-chain of the class where we are included into:
        serialize :i18n   # we should also protect it from direct assignment by the user
        
        # if Mongoid::Document is in the list of classes which extends the class we are included into:
        #    field :i18n, type: Hash
        # but on the other hand, Mongoid now supports "localized fields" -- so we don't need to re-implement this.
        # Yay! Durran Jordan is awesome! :-) See: http://mongoid.org/docs/documents/localized.html
        # 
        # NOTE: I like how Durran implemented the localization in Mongoid.. too bad I didn't see that before.
        # I'm thinking of re-writing this gem to store the localization hash per attribute... hmm... hmm... thinking...
        # there would be a couple of advantages to store the I18n-hash per attribute:
        #   - drop-in internationalization for existing String type attributes
        #   - works well with rails scaffolding and with protection of attributes (attr_protected / attr_accessible)
        #   - we can easily hide the internal hash by re-defining the attr-accessors for doing the I18n
        #   - we can better add the per-attribute versioning, which is planned
        #   - 

        after_initialize :initialize_i18n_hashes


        # dynamically define the accessors for the translated attributes:

        translated_attribute_names.each do |attr_name|
          class_eval do 
            # define the getter method
            define_method(attr_name) do |locale = I18n.locale|
              if ! self.i18n.has_key?(locale)
                return self.i18n[ I18n.default_locale ][attr_name] if ActsAsI18n.fallback?
                return nil
              end
              self.i18n[ locale ][attr_name]
            end

          # define the setter method
            define_method(attr_name.to_s+ '=') do |new_translation|
              self.i18n[I18n.locale] ||= HashWithIndifferentAccess.new
              self.i18n[I18n.locale][attr_name] = new_translation
            end
          end
        end
      end

      def translates?
        included_modules.include?(InstanceMethods)
      end
    end
  end
end
