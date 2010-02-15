module ConstantContact
  class Contact < BaseResource

    attr_reader :uid, :contact_lists

    def initialize( params={}, from_contact_list=false )
      return false if params.empty?
      
      @uid = params['id'].split('/').last
      @contact_lists = []

      if from_contact_list
        fields = params['content']['ContactListMember']
      else
        fields = params['content']['Contact']
      end

      if lists = fields.delete( 'ContactLists' )
        @contact_lists = lists['ContactList'].collect { |list| list['id'].split('/').last }
      end

      fields.each do |k,v|
        underscore_key = underscore( k )
        
        instance_eval %{
          @#{underscore_key} = "#{v}"

          def #{underscore_key}
            @#{underscore_key}
          end
        }
      end

    end

    class << self
      
      # Get a summary list all contacts
      def all( options={} )
        contacts = []

        data = ConstantContact.get( '/contacts', options )
        return contacts if ( data.nil? or data.empty? )

        data['feed']['entry'].each do |entry|
          contacts << new( entry )
        end

        contacts
      end
      
      # Add a new contact
      #
      # Available data fields are
      # * EmailAddress
      # * EmailType
      # * FirstName
      # * MiddleName
      # * LastName
      # * JobTitle
      # * CompanyName
      # * HomePhone
      # * WorkPhone
      # * Addr1
      # * Addr2
      # * Addr3
      # * City
      # * StateCode => Must be valid US/Canada Code (http://ui.constantcontact.com/CCSubscriberAddFileFormat.jsp#states)
      # * StateName
      # * CountryCode = Must be valid code (http://constantcontact.custhelp.com/cgi-bin/constantcontact.cfg/php/enduser/std_adp.php?p_faqid=3614)
      # * CountryName
      # * PostalCode
      # * SubPostalCode
      # * Note
      # * CustomField[1-15]
      # * ContactLists
      # * OptInSource
      # * OptOutSource
      # 
      def add( data={}, opt_in='ACTION_BY_CUSTOMER', options={} )
        raise "MUST IMPLEMENT CONTACT LISTS FIRST"
        xml = build_contact_xml_packet( data, opt_in )

        options.merge!({ :body => xml })
        data = ConstantContact.post( "/contacts", options )

        # check response.code
        # if successful, data == 'updated'
        # if failure, data == 'updated'

        raise "response code: #{data.code}"
        if data.code <= 204 # successful response
          # get the Contact and return it
        else # failed response
          return nil
        end
      end
      
      # Get detailed record for a single contact by id
      def get( id, options={} )
        data = ConstantContact.get( "/contacts/#{id.to_s}", options )
        return nil if ( data.nil? or data.empty? )
        new( data['entry'] )
      end
      
      # Update a single contact record
      def update( id, data )
      end
      
      # Search for a contact by email address or last updated date
      def search( options={} )
      end

      private

      def build_contact_xml_packet( data={}, opt_in='ACTION_BY_CUSTOMER' )
        xml = <<EOF
<entry xmlns="http://www.w3.org/2005/Atom">
  <title type="text"></title>
  <updated>#{Time.now.strftime("%Y-%m-%dT%H:%M:%S.000Z")}</updated>
  <author></author>
  <id>NA</id>
  <summary type="text">Contact</summary>
  <content type="application/vnd.ctct+xml">
    <Contact xmlns="http://ws.constantcontact/ns/1.0/">
EOF
        
        data.each do |key, val|
          node = camelize(key.to_s)

          if key == :contact_lists
            # FIXME: add in <ContactLists> entry here
            # <ContactLists>
            #   <ContactList id="http://api.constantcontact.com/ws/customers/geeksquad/joesflowers/lists/1" />
            # </ContactLists>
          else
            xml << %Q(      <#{node}>#{val}</#{node}>\n)
          end
        end

        xml += <<EOF
      <OptInSource>#{opt_in}</OptInSource>
    </Contact>
  </content>
</entry>
EOF

        xml
      end

    end

  end
end
