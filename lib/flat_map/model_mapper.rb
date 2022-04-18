module FlatMap
  # == Mapper
  #
  # FlatMap mappers are designed to provide complex set of data, distributed over
  # associated AR models, in the simple form of a plain hash. They accept a plain
  # hash of the same format and distribute its values over deeply nested AR models.
  #
  # To achieve this goal, Mapper uses three major concepts: Mappings, Mountings and
  # Traits.
  #
  # === Mappings
  #
  # Mappings are defined view Mapper.map method. They represent a simple one-to-one
  # relation between target attribute and a mapper, extended by additional features
  # for convenience. The best way to show how they work is by example:
  #
  #   class CustomerMapper < FlatMap::Mapper
  #     # When there is no need to rename attributes, they can be passed as array:
  #     map :first_name, :last_name
  #
  #     # When hash is used, it will map field name to attribute name:
  #     map :dob => :date_of_birth
  #
  #     # Also, additional options can be used:
  #     map :name_suffix, :format => :enum
  #     map :password, :reader => false, :writer => :assign_password
  #
  #     # Or you can combine all definitions together if they all are common:
  #     map :first_name, :last_name,
  #         :dob    => :date_of_birth,
  #         :suffix => :name_suffix,
  #         :reader => :my_custom_reader
  #   end
  #
  # When mappings are defined, one can read and write values using them:
  #
  #   mapper = CustomerMapper.find(1)
  #   mapper.read          # => {:first_name => 'John', :last_name => 'Smith', :dob => '02/01/1970'}
  #   mapper.write(params) # will assign same-looking hash of arguments
  #
  # Following options may be used when defining mappings:
  # [<tt>:format</tt>] Allows to additionally process output value on reading it. All formats are
  #                    defined within FlatMap::Mapping::Reader::Formatted::Formats and
  #                    specify the actual output of the mapping
  # [<tt>:reader</tt>] Allows you to manually control reader value of a mapping, or a group of
  #                    mappings listed on definition. When String or Symbol is used, will call
  #                    a method, defined by mapper class, and pass mapping object to it. When
  #                    lambda is used, mapper's target (the model) will be passed to it.
  # [<tt>:writer</tt>] Just like with the :reader option, allows to control how value is assigned
  #                    (written). Works the same way as :reader does, but additionally value is
  #                    sent to both mapper method and lambda.
  # [<tt>:multiparam</tt>] If used, multiparam attributes will be extracted from params, when
  #                        those are passed for writing. Class should be passed as a value for
  #                        this option. Object of this class will be initialized with the arguments
  #                        extracted from params hash.
  #
  # === Mountings
  #
  # Mappers may be mounted on top of each other. This ability allows host mapper to gain all the
  # mappings of the mounted mapper, thus providing more information for external usage (both reading
  # and writing). Usually, target for mounted mapper may be obtained from association of target of
  # the host mapper itself, but may be defined manually.
  #
  #   class CustomerMapper < FlatMap::Mapper
  #     map :first_name, :last_name
  #   end
  #
  #   class CustomerAccountMapper < FlatMap::Mapper
  #     map :source, :brand, :format => :enum
  #
  #     mount :customer
  #   end
  #
  #   mapper = CustomerAccountMapper.find(1)
  #   mapper.read # => {:first_name => 'John', :last_name => 'Smith', :source => nil, :brand => 'FTW'}
  #   mapper.write(params) # Will assign params for both CustomerAccount and Customer records
  #
  # The following options may be used when mounting a mapper:
  # [<tt>:mapper_class</tt>] Specifies mapper class if it cannot be determined from mounting itself
  # [<tt>:mapper_class_name</tt>] Alternate string form of class name instead of mapper_class.
  # [<tt>:target</tt>] Allows to manually specify target for the new mapper. May be an object or lambda
  #                    with arity of one that accepts host mapper target as argument. Comes in handy
  #                    when target cannot be obviously detected or requires additional setup:
  #                    <tt>mount :title, :target => lambda{ |customer| customer.title_customers.build.build_title }</tt>
  # [<tt>:traits</tt>] Specifies list of traits to be used by mounted mapper
  # [<tt>:suffix</tt>] Specifies the suffix that will be appended to all mappings and mountings of mapper,
  #                    as well as mapper name itself.
  #
  # === Traits
  #
  # Traits allow mappers to encapsulate named sets of additional definitions, and use them optionally
  # on mapper initialization. Everything that can be defined within the mapper may be defined within
  # the trait. In fact, from the implementation perspective traits are mappers themselves that are
  # mounted on the host mapper.
  #
  #   class CustomerAccountMapper < FlatMap::Mapper
  #     map :brand, :format => :enum
  #
  #     trait :with_email do
  #       map :source, :format => :enum
  #
  #       mount :email_address
  #
  #       trait :with_email_phones_residence do
  #         mount :customer, :traits => [:with_phone_numbers, :with_residence]
  #       end
  #     end
  #   end
  #
  #   CustomerAccountMapper.find(1).read # => {:brand => 'TLP'}
  #   CustomerAccountMapper.find(1, :with_email).read # => {:brand => 'TLP', :source => nil, :email_address => 'j.smith@gmail.com'}
  #   CustomerAccountMapper.find(1, :with_email_phone_residence).read # => :brand, :source, :email_address, phone numbers,
  #                                    #:residence attributes - all will be available for reading and writing in plain hash
  #
  # === Extensions
  #
  # When mounting a mapper, one can pass an optional block. This block is used as an extension for a mounted
  # mapper and acts as an anonymous trait. For example:
  #
  #   class CustomerAccountMapper < FlatMap::Mapper
  #     mount :customer do
  #       map :dob => :date_of_birth, :format => :i18n_l
  #       validates_presence_of :dob
  #
  #       mount :unique_identifier
  #
  #       validates_acceptance_of :mandatory_agreement, :message => "You must check this box to continue"
  #     end
  #   end
  #
  # === Validation
  #
  # <tt>FlatMap::Mapper</tt> includes <tt>ActiveModel::Validations</tt> module, allowing each model to
  # perform its own validation routines before trying to save its target (which is usually AR model). Mapper
  # validation is very handy when mappers are used with Rails forms, since there no need to lookup for a
  # deeply nested errors hash of the AR models to extract error messages. Mapper validations will attach
  # messages to mapping names.
  #
  # Mapper validations become even more useful when used within traits, providing way of very flexible validation sets.
  #
  # === Callbacks
  #
  # Since mappers include <tt>ActiveModel::Validation</tt>, they already support ActiveSupport's callbacks.
  # Additionally, <tt>:save</tt> callbacks have been defined (i.e. there have been define_callbacks <tt>:save</tt>
  # call for <tt>FlatMap::Mapper</tt>). This allows you to control flow of mapper saving:
  #
  #   set_callback :save, :before, :set_model_validation
  #
  #   def set_model_validation
  #     target.use_validation :some_themis_validation
  #   end
  #
  # === Skipping
  #
  # In some cases, it is required to omit mapper processing after it has been created within mounting chain. If
  # <tt>skip!</tt> method is called on mapper, it will return <tt>true</tt> for <tt>valid?</tt> and <tt>save</tt>
  # method calls without performing any other operations. For example:
  #
  #   class CustomerMapper < FlatMap::Mapper
  #     # some definitions
  #
  #     trait :product_selection do
  #       attr_reader :selected_product_id
  #
  #       mount :product
  #
  #       set_callback :validate, :before, :ignore_new_product
  #
  #       def ignore_new_bank_account
  #         mounting(:product).skip! if product_selected?
  #       end
  #
  #       # some more definitions
  #     end
  #   end
  #
  # === Attribute Methods
  #
  # All mappers have the ability to read and write values via method calls:
  #
  #   mapper.read[:first_name] # => John
  #   mapper.first_name # => 'John'
  #   mapper.last_name = 'Smith'
  class ModelMapper < OpenMapper
    extend ActiveSupport::Autoload

    autoload :AssociationsList
    autoload :Persistence
    autoload :Skipping

    include AssociationsList
    include Persistence
    include Skipping

    delegate :logger, :to => :target
  end
end
