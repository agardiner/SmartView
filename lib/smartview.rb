require 'benchmark'
require 'httpclient'
require 'builder'
require 'hpricot'

require 'smartview/request'
require 'smartview/preferences'
require 'smartview/grid'


class SmartView

    CLIENT_XML_VERSION = "3.1.0.0.0"

    class SmartViewException < RuntimeError
        def initialize(xml)
            super(xml.at('desc').to_plain_text)
            @err_code = xml['errcode']
            @native_error = xml['native']
            @type = xml['type']
            @details = xml.at('/details') && xml.at('/details').to_plain_text
        end
    end

    class AlreadyConnected < RuntimeError; end
    class NotConnected < RuntimeError; end
    class NotAttached < RuntimeError; end


    attr_reader :session_id, :provider
    attr_reader :user, :sso
    attr_reader :preferences


    # Create a SmartView connection for the specified provider URL.
    def initialize(provider_url, logger=nil)
        @url = provider_url
        @req = Request.new
        @preferences = Preferences.new
        @http = HTTPClient.new
        @http.proxy = nil
        unless logger
            require 'logger'
            logger = Logger.new(STDOUT)
        end
        @logger = logger
    end


    # Sets the preferences to be applied to this session.
    def preferences=(prefs)
        unless prefs.kind_of? Preferences
            raise InvalidPreference, "Preference settings must be an instance of SmartView::Preferences"
        end
        @preferences = prefs
    end


    # Connect to the SmartView provider and obtain a session id.
    # Two methods of connection are supported:
    # 1. Userid and password
    # 2. SSO token
    # If only a single parameter is passed, the SSO method is assumed; if two
    # parameters are passed, these are assumed to be userid and password.
    def connect(user_or_sso, password = nil)
        if @provider
            raise AlreadyConnected, "Cannot change provider once connected" if @provider
        end

        # Obtain a session id
        if password.nil?
            # Connect via SSO token
            @sso = user_or_sso
            @logger.info "Connecting to #{@url} using SSO token"
            @req.ConnectToProvider do |xml|
                xml.ClientXMLVersion CLIENT_XML_VERSION
                xml.sso @sso
                xml.lngs({:enc => 0}, "en_US")
            end
        else
            # Connect via userid and password
            @user = user_or_sso
            @password = password
            @logger.info "Connecting to #{@url} using userid/password"
            @req.ConnectToProvider do |xml|
                xml.ClientXMLVersion CLIENT_XML_VERSION
                xml.usr @user
                xml.pwd @password
                xml.lngs({:enc => 0}, "en_US")
            end
        end
        doc = invoke
        @session_id = doc.at('//res_ConnectToProvider/sID').inner_html
        set_provider doc.at('//res_ConnectToProvider/provider').inner_html
    end


    # Open an application via the configured SmartView provider.
    def open_app(server, app, cube)
        raise NotConnectedError, "No provider connection established" unless @session_id && @provider

        # Reset app state
        @dimensions = nil

        # Connect to application
        @logger.info "Opening cube #{app}.#{cube} on #{server}"
        @req.OpenApplication do |xml|
            xml.sID @session_id
            if @sso
                xml.sso @sso
            else
                xml.usr @user
                xml.pwd @password
            end
            xml.srv server
            xml.app app
        end
        invoke

        # Obtain an SSO token for subsequent use
        unless @sso
            @req.GetSSOToken do |xml|
                xml.sID @session_id
            end
            @sso = invoke.at('//res_GetSSOToken/sso').inner_html
            @password = nil     # Don't remember password any longer than we need to
        end

        # Open cube
        @req.OpenCube do |xml|
            xml.sID @session_id
            xml.srv server
            xml.app app
            xml.cube cube
        end
        invoke
        @app = app
        @cube = cube

        # Get default POV
        default_pov
    end


    # Close the connection to the current application cube.
    def close_app
        if @session_id && @app
            @logger.info "Disconnecting from #{@app}.#{@cube}"
            @req.Logout do |xml|
                xml.sID @session_id
            end
            invoke
            @app = nil
            @cube = nil
            @dimensions = nil
            @default_pov = nil
        end
    end


    # Retrieve a list of dimensions for the current connection.
    def get_dimensions
        check_attached

        @logger.info "Retrieving list of dimensions"
        @req.EnumDims do |xml|
            xml.sID @session_id
            xml.alsTbl @preferences.alias_table
        end
        @dimensions = []
        invoke.search('//res_EnumDims/dimList/dim').each do |dim|
            @dimensions[dim['id'].to_i] = dim['name']
        end
        @dimensions
    end


    # Returns a list of available member filters for the specified dimension.
    # A filter can be used to restrict a member query to a certain subset of
    # members, such as the members in a member list.
    def get_filters(dimension)
        check_attached

        @logger.info "Retrieving list of available member filters for #{dimension}"
        @req.EnumFilters do |xml|
            xml.sID @session_id
            xml.dim dimension
        end
        doc = invoke
        filters = []
        invoke.search('//res_EnumFilters/filterList/filter').each do |filter|
            filters << filter['name']
        end
        filters
    end


    # Retrieves a list of members for the specified dimension, optionally
    # satisfying a filter.
    def get_members(dimension, filter = default_filter(dimension), all_gens = true)
        check_attached

        filter, filter_args = member_to_filter(filter)
        @logger.info "Retrieving list of members for #{dimension}"
        @req.EnumMembers do |xml|
            xml.sID @session_id
            xml.dim dimension
            xml.memberFilter do |xml|
                xml.filter('name' => filter) do |xml|
                    insert_filter_args xml, filter_args
                end
            end
            xml.getAtts '0'
            xml.alsTbl @preferences.alias_table
            xml.allGenerations all_gens ? '1' : '0'
        end
        doc = invoke
        members = doc.at('//res_EnumMembers/mbrs').to_plain_text.split('|')
        members
    end


    # Search for the specified member name or pattern in a dimension.
    # Returns an array of arrays, each inner array representing a path to a
    # matching member.
    def find_member(dimension, pattern)
        check_attached

        @logger.info "Finding members of #{dimension} matching '#{pattern}'"
        @req.FindMember do |xml|
            xml.sID @session_id
            xml.dim dimension
            xml.mbr pattern
            filter_name, filter_args = process_filter(dimension)
            xml.filter 'name' => filter_name do |xml|
                insert_filter_args xml, filter_args
            end
            xml.alsTbl @preferences.alias_table
        end
        doc = invoke
        path_list = []
        doc.search('//res_FindMember/pathList/path').each do |path|
            path_list << path.at('mbrs').to_plain_text.split('|')
        end
        path_list
    end


    # Sets the current POV
    def pov=(new_pov)
        new_pov
        @pov = pov.merge(new_pov)
    end


    # Returns a hash indicating the current POV
    def pov
        default_pov unless @pov
        @pov
    end


    # Get the default POV
    def default_pov
        # Make sure we are connected
        check_attached

        @logger.info "Retrieving default POV"
        @req.GetDefaultPOV do |xml|
            xml.sID @session_id
            xml.getAtts '0'
            xml.alsTbl @preferences.alias_table
        end
        doc = invoke
        dims = doc.at('//res_GetDefaultPOV/dims').to_plain_text.split('|')
        @dimensions = dims unless @dimensions
        mbrs = doc.at('//res_GetDefaultPOV/mbrs').to_plain_text.split('|')
        @pov = {}
        0.upto(dims.size-1) do |i|
            @pov[dims[i]] = mbrs[i]
        end
        @pov
    end


    # Gets a default grid with the specified POV
    def default_grid
        # Make sure we are attached to a cube
        check_attached

        @logger.info "Retrieving default grid"
        @req.GetDefaultGrid do |xml|
            xml.sID @session_id
            @preferences.inject_xml xml, @provider_type
            xml.backgroundpov do |xml|
                pov.each do |dim,mbr|
                    xml.dim :name => dim, :pov => mbr
                end
            end
        end
        doc = invoke
        Grid.from_xml(doc)
    end


    # Refresh a grid from the current provider
    def refresh(grid)
        # Make sure we are attached to a cube
        check_attached

        @logger.info "Refreshing grid"
        @req.Refresh do |xml|
            xml.sID @session_id
            @preferences.inject_xml xml, @provider_type
            grid.to_xml(xml)
        end
        doc = invoke
        Grid.from_xml(doc)
    end


    # Return a grid for the spcified rows and columns and optional POV
    # The rows must be a hash whose key is a single dimension name, or array of
    # dimension names. The value of the hash must be an array containing tuples
    # of member names for the dimension(s) in the rows.
    # The cols must be a hash whose key is a single dimension name, or array of
    # dimension names. The value of the hash must be an array containing tuples
    # of member names for the dimension(s) in the cols.
    # The pov is an optional POV that will be merged with the current POV to
    # determine the retrieved POV.
    def free_form_grid(rows, cols, grid_pov=nil)
        # Make sure we are attached to a cube
        check_attached
        get_dimensions unless @dimensions

        # Update the POV if one is specified
        if grid_pov
            self.pov = grid_pov
        end

        grid = Grid.define(@dimensions, pov, rows, cols)

        @logger.info "Retrieving free-form grid"
        @req.ProcessFreeFormGrid do |xml|
            xml.sID @session_id
            @preferences.inject_xml xml, @provider_type
            xml.backgroundpov do |xml|
                pov.each do |dim,mbr|
                    xml.dim :name => dim, :pov => mbr
                end
            end
            grid.to_xml(xml, false)
            grid.dims_to_xml(xml)
        end
        doc = invoke
        grid = Grid.from_xml(doc)

        # The grid returned does not contain data, so perform a refresh
        refresh(grid)
    end


private

    # Loads provider-specific functionality
    def set_provider(provider)
        @provider = provider
        case @provider
            when /Financial Management/
                require 'smartview/hfm_provider'
                self.extend HFMProvider
                @provider_type = :HFM
            when /Analytic Services/
                require 'smartview/essbase_provider'
                self.extend EssbaseProvider
                @provider_type = :Essbase
        end
    end


    # Checks to see that a session has been established, raising a NotConnected
    # exception if one has not.
    def check_connected
        raise NotConnected unless @session_id && @sso && @provider
    end


    # Checks that a cube is open, raising a NotAttached exception if one is not.
    def check_attached
        check_connected
        raise NotAttached unless @app && @cube
    end


    # Sends the current request XML to the SmartView provider, and parses the
    # response with hpricot.
    # If an exception was returned, an SmartViewException is raised with the
    # details of the error.
    def invoke
        resp = nil
        ms = Benchmark.realtime do
            resp = @http.post @url, @req.to_s
        end
        @logger.info 'SmartView request %s completed in %.1fs' % [@req.method, ms]
        doc = Hpricot::XML(resp.body.content)
        if !doc.at("//res_#{@req.method}")
            @logger.error "Error invoking SmartView method #{@req.method}"
            @logger.debug "Request was:\n#{@req}"
            @logger.debug "Response was:\n#{resp.body.content}"
            if ex = doc.at('//exception')
                ex = SmartViewException.new(ex)
                @logger.error "An exception occurred in #{@req.method}"
                @logger.error ex
                raise ex
            else
                @logger.error "Unexpected response from SmartView provider:\n#{doc.to_plain_text}"
                raise RuntimeError, "Unexpected response from SmartView provider: #{doc.to_plain_text}"
            end
        end
        doc
    end


    # Converts a member specification of the form {mbr.[filter]} to a filter
    # name and a filter argument.
    def member_to_filter(member)
        member =~ /^\{?(?:([^.]+)\.)?(\[?[^\]]+\]?)\}?$/
        return $2, $1
    end


    # Insert filter arguments to a request
    def insert_filter_args(xml, filter_args)
        if filter_args
            filter_args.each_with_index do |filter_arg, i|
                xml.arg({'id' => "#{i}"}, filter_arg)
            end
        end
    end

end
