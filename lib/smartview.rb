require 'httpclient'
require 'builder'
require 'hpricot'

require 'smartview/request'
require 'smartview/preferences'
require 'smartview/grid'


class SmartView

    CLIENT_XML_VERSION = "3.1.0.0.0"

    GRID_TYPE_UPPER_LEFT = '7'
    GRID_TYPE_MEMBER = '0'
    GRID_TYPE_DATA = '2'

    class SmartViewException < RuntimeError
        def initialize(xml)
            super(xml.at('desc').inner_html)
            @err_code = xml['errcode']
            @native_error = xml['native']
            @type = xml['type']
            @details = xml.at('/details')
        end
    end

    class InvalidPreference < RuntimeError; end
    class NotConnected < RuntimeError; end


    attr_reader :session_id, :provider
    attr_accessor :user, :password, :sso
    attr_reader :preferences


    # Utility method for building up a tuple by cross-joining sets for each dimension
    def self.cross_join(*args)
        result = nil
        args.each do |arg|
            return nil if arg.nil?
            arg = [arg] unless arg.is_a? Array
            if result
                new_result = []
                result.each do |tuple|
                    arg.each do |next_val|
                        new_result << (tuple.is_a?(Array) ? tuple : [tuple]) + [next_val]
                    end
                end
                result = new_result
            else
                # First dimension added to result
                result = arg
            end
        end
        result
    end


    # Create a SmartView connection for the specified provider URL.
    def initialize(provider_url)
        @url = provider_url
        @req = Request.new
        @preferences = Preferences.new
        @http = HTTPClient.new
        @http.proxy = nil
    end


    # Connect to the SmartView provider and obtain a session id.
    # Two methods of connection are supported:
    # 1. Userid and password
    # 2. SSO token
    # The SSO method will be used if the sso instance variable is set;
    # otherwise, the userid and password will be used.
    def connect
        # Obtain a session id
        if @sso
            # Connect via SSO token
            @req.ConnectToProvider do |xml|
                xml.ClientXMLVersion CLIENT_XML_VERSION
                xml.sso @sso
                xml.lngs({:enc => 0}, "en_US")
            end
        else
            # Connect via userid and password
            @req.ConnectToProvider do |xml|
                xml.ClientXMLVersion CLIENT_XML_VERSION
                xml.usr @user
                xml.pwd @password
                xml.lngs({:enc => 0}, "en_US")
            end
        end
        doc = invoke
        @session_id = doc.at('//res_ConnectToProvider/sID').inner_html
        @provider = doc.at('//res_ConnectToProvider/provider').inner_html
    end


    # Open an application via the current provider
    def open_app(server, app, cube)
        raise NotConnectedError, "No provider connection established" unless @session_id && @provider

        # Reset app state
        @dimensions = nil
        @alias_table = 'none'

        # Connect to application
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
    end


    # Disconnect from the application
    def disconnect
        @req.Logout do |xml|
            xml.sID @session_id
        end
        invoke
        @session_id = nil
        @provider = nil
    end


    # Get the default POV
    def default_pov
        # Make sure we are connected
        check_connected

        @req.GetDefaultPOV do |xml|
            xml.sID @session_id
            xml.getAtts '0'
            xml.alsTbl @alias_table
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


    # Gets a default grid with the specified POV
    def default_grid
        # Make sure we are connected
        check_connected

        @req.GetDefaultGrid do |xml|
            xml.sID @session_id
            @preferences.inject_xml xml
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
        # Make sure we are connected
        check_connected

        @req.Refresh do |xml|
            xml.sID @session_id
            @preferences.inject_xml xml
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
        # Make sure we are connected
        check_connected
        get_dimensions unless @dimensions

        # Update the POV if one is specified
        if grid_pov
            self.pov = grid_pov
        end

        grid = Grid.define(@dimensions, pov, rows, cols)

        @req.ProcessFreeFormGrid do |xml|
            xml.sID @session_id
            @preferences.inject_xml xml
            xml.backgroundpov do |xml|
                pov.each do |dim,mbr|
                    xml.dim :name => dim, :pov => mbr
                end
            end
            xml.backgroundpov do |xml|
                pov.each do |dim,mbr|
                    xml.dim :name => dim, :pov => mbr
                end
            end
            grid.to_xml(xml, false)
            grid.dims_to_xml(xml)
        end
        doc = invoke
        Grid.from_xml(doc)
    end


private

    # Checks to see that a session has been established, raising a NotConnected
    # exception if one has not.
    def check_connected
        raise NotConnected unless @session_id && @sso && @provider
    end


    # Retrieve a list of dimensions for the current connection
    def get_dimensions
        @req.EnumDims do |xml|
            xml.sID @session_id
            xml.alsTbl @alias_table
        end
        @dimensions = []
        invoke.search('//res_EnumDims/dimList/dim').each do |dim|
            @dimensions[dim['id'].to_i] = dim['name']
        end
    end


    # Sends the current request XML to the SmartView provider, and parses the
    # response with hpricot.
    # If an exception was returned, an HFMException is raised with the details
    # of the error.
    def invoke
        puts "Invoking #{@req.method}"
        resp = @http.post @url, @req.to_s
        doc = Hpricot::XML(resp.body.content)
        if !doc.at("//res_#{@req.method}")
            puts "Error invoking SmartView method #{@req.method}:"
            if ex = doc.at('//exception')
                raise SmartViewException.new(ex)
            else
                raise RuntimeError, "Unexpected response from SmartView provider: #{doc.to_plain_text}"
            end
        end
        doc
    end
end
