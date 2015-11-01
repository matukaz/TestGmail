-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

-- Your code here
local gmailtext


local gConnect = require("googlelogin")
function connectCallback(event)
    if(not event.isError) then
        gConnect.api("https://www.googleapis.com/oauth2/v1/userinfo", "GET", function(event)
            local answer = event.response
            


            local options = 
            {
                --parent = textGroup,
                text = answer,     
                x = display.actualContentWidth/2,
                y = 200,
                width = display.actualContentWidth-100,     --required for multi-line and alignment
                font = native.systemFontBold,   
                fontSize = 10,
                align = "left"  --new alignment parameter
            }

            gmailtext = display.newText( options )
            gmailtext:setFillColor( 1, 0, 0 )




        end)
    end
end
gConnect.connect(connectCallback)


local myText = display.newText( "Hello,\n Thanks for trying to help me.\n install APK in your phone and login,\n some text about your account should appear.\n I need to somehow get your name. ", 150, 0, native.systemFont, 10)
myText:setFillColor( 1, 1, 0 )

