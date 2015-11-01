---
-- Connecting with Google via OAUTH2
-- @version 1.0
-- @author Cassiozen
-- @license MIT License
--- https://developers.google.com/identity/protocols/OpenIDConnect

--https://console.developers.google.com/project/gymdiary-1065/apiui/consent?createClient



--[[
https://github.com/nitin007/corona-googleConnect
Basic Usage

Require The Code

local gConnect = require("googleConnect")
Call "connect" passing a callback as a parameter.

If the user never used the app, it will open a WebPopUp so the user can authorize the app. The module will save the user refresh token and try to use it on all subsequent usages without presenting a webPopUp again.

gConnect.connect(callback)
On your callback function (or anytime after the callback was called, you can call google APIs using google.api(URL, METHOD, CALLBACK), for example:

google.api("https://www.googleapis.com/oauth2/v1/userinfo", "GET", function(event)
    print(event.response)
end)
The complete example would be:

local gConnect = require("googleconnect")
function connectCallback(event)
    if(not event.isError) then
        gConnect.api("https://www.googleapis.com/oauth2/v1/userinfo", "GET", function(event)
            print(event.response)
        end)
    end
end
gConnect.connect(connectCallback)

--]]



module(...,package.seeall)
local socket = require("socket")
local json = require("json")
local credentials
local connectCallback

local options = {}
options.client_id = "859434582383-jpjhk7nqiojiil0a5trhl00vbiunu7a7.apps.googleusercontent.com"
options.client_secret = "kv_AqFkZiKAqu8TRLej0H2NO"
options.scope = "https://www.googleapis.com/auth/userinfo.email+https://www.googleapis.com/auth/userinfo.profile" -- Set your desired scopes. More info at https://developers.google.com/accounts/docs/OAuth2Login#scopeparameter
options.response_type = "code"
options.redirect_uri = "http://localhost:9004"

g = {}

-- Opens a webpopup so user can login at google and authorize app. Starts internal TCP server to listen to Google's redirect
function authenticateUser()
	startServer()
	local authUrl = string.format("https://accounts.google.com/o/oauth2/auth?scope=%s&redirect_uri=%s&response_type=%s&client_id=%s", options.scope, options.redirect_uri, options.response_type, options.client_id)
	native.showWebPopup( 10, 40, 300, 440, authUrl)
end

-- Saves the user's refresh token on a json file
function saveRefreshToken()
    local file = io.open(system.pathForFile("googleAccount.json", system.DocumentsDirectory), "w")
    if file then
        file:write( json.encode({refreshToken = credentials["refresh_token"]}) )
        io.close( file )
    end
end

-- Callback for requestCredentials and requestToken methods
-- Gets the user token and call's the callback passed as parameter on g.connect
function requestCredentialsCallback( event )
	-- Prepares the table to return
	local connectedResponse = {
    	name = "connected",
    	response = event.response
	}
	-- Check for connection errors
    if ( event.isError ) then
    	connectedResponse.isError = true
    	pcall(connectCallback, connectedResponse)
    else
        credentials = json.decode(event.response)
         -- Check if user hasn't revoked access
        if (credentials["error"]) then
        	-- If so, delete the refreshtoken persisted data and try login in again
			os.remove( system.pathForFile("googleAccount.json", system.DocumentsDirectory) )
			authenticateUser()
			return
        end
        -- If there's a refrsh token, save it on a json file for later use
        if(credentials["refresh_token"]) then saveRefreshToken() end
        connectedResponse.isError = false
        pcall(connectCallback, connectedResponse)
    end
    connectCallback = nil
end

-- Request user's access and refresh tokens
function requestCredentials(code)
	local params = {}
	params.body = string.format("code=%s&client_id=%s&client_secret=%s&redirect_uri=%s&grant_type=authorization_code", code, options.client_id, options.client_secret, options.redirect_uri)
	network.request( "https://accounts.google.com/o/oauth2/token", "POST", requestCredentialsCallback, params)
end

-- Request a new user's access token using a refresh token
function requestToken(refreshToken)
	local params = {}
	params.body = string.format("refresh_token=%s&client_id=%s&client_secret=%s&grant_type=refresh_token", refreshToken, options.client_id, options.client_secret)
	network.request( "https://accounts.google.com/o/oauth2/token", "POST", requestCredentialsCallback, params)
end

-- Listen to the httprequest google does on local ServerSocket
function redirectCallback(request)
	-- Sample succes request
	-- GET /?code=4/lNorA-RhjdU87F7XfTV3ib8oeqOX.ItKgfHhj74fHshQV0ieZDAqsb31Aqui HTTP/1.1
	-- Sample error response
	-- GET /?error=access_denied HTTP/1.1

	-- Check if the returned request header contains a code or an error
	-- TODO: Check if this regexes are really working on all conditions on all kinds of users
	local errors = string.match(request, "GET /??error=([%w_/.=?]+)")
	local code = string.match(request, "GET /??code=([%w--_/.=?]+)")
	if(errors or not code) then
		-- Something went wrong. Try authenticating again
		authenticateUser()
		return
	else 
		native.cancelWebPopup()
		requestCredentials(code)
	end
end

-- Starts a local TCP server to listen to Google redirect callback
function startServer()
	-- Create Socket
	local tcpServerSocket , err = socket.tcp()
	local backlog = 0

	-- Check Socket
	if tcpServerSocket == nil then
	return nil , err
	end

	-- Allow Address Reuse
	tcpServerSocket:setoption( "reuseaddr" , true )

	-- Bind Socket
	local res, err = tcpServerSocket:bind( "*" , "9004" )
	if res == nil then
	return nil , err
	end

	-- Check Connection
	res , err = tcpServerSocket:listen( backlog )
	if res == nil then
	return nil , err
	end

	serverTimer = timer.performWithDelay(10, function() 
		tcpServerSocket:settimeout( 0 )
		client = tcpServerSocket:accept()
		if (client ~= nil) then
			ip, port = client:getpeername()
			print("Got connection from ".. ip .. " on port " .. port)

			local request, err = client:receive()
			if not err then
				client:close()
				timer.cancel(serverTimer)
				redirectCallback(request)
			end
		end
	end, 0)
end


g.connect = function(callback) 
	connectCallback = callback

	local file = io.open(system.pathForFile("googleAccount.json", system.DocumentsDirectory), "r")
	-- First, check if it's a saved refresh token, so we can authenticate user without prompting him to enter login and password
    if file then
        local googleAccount = json.decode(file:read( "*a" ))
      
        io.close( file )
        requestToken(googleAccount["refreshToken"])
    -- If we don't have a refresh token, open a webPopup so he can log in
    else
    	authenticateUser()
	end
end

g.api = function(url, method, callback)

	local apiResponse = {
    	name = "apiResponse",
	}

	if(not credentials) then
		apiResponse.isError = true
		apiResponse.response = "Token not aquired."
		pcall(callback, apiResponse)
	else
		local headers = {}
		headers["Authorization"] = "Bearer " .. credentials["access_token"]
		local params = {}
		params.headers = headers

		network.request(url, method, function(event) 
			apiResponse.isError = event.isError
			apiResponse.response = event.response
			
			pcall(callback, apiResponse)
		end,  params)
	end
end

return g