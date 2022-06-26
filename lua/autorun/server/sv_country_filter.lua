-- Script maked by PrikolMen#3372 with love <3
local cvars_AddChangeCallback = cvars.AddChangeCallback
local CreateConVar = CreateConVar
local isstring = isstring
local tobool = tobool

/*

    All convars:
    - sv_cf_reason ""
    - sv_cf_blacklist ""
    - sv_cf_kick_on_failure <0/1>
    - sv_cf_steamid_blacklist <0/1>
    - sv_cf_blacklist_is_whitelist <0/1>

*/

-- game.KickID64
do

    local util_SteamIDFrom64 = util.SteamIDFrom64
    local game_KickID = game.KickID

    function game.KickID64( steamid64, reason )
        game_KickID( util_SteamIDFrom64( steamid64 ), reason )
    end

end

local script_name = "country_filter"
module( script_name, package.seeall )

-- country_filter.FormatCountries
do

    local string_Split = string.Split
    local string_gsub = string.gsub
    local ipairs = ipairs

    function FormatCountries( str )
        local countries = {}

        if isstring( str ) then
            for key, value in ipairs( string_Split( string_gsub( str, "([%w_]+)%s*", "%1 " ), " " ) ) do
                if (value == "") then continue end
                countries[ value:lower() ] = true
            end
        end

        return countries
    end

end

-- country_filter.IsAllowedCountry
do

    local blacklist = FormatCountries( CreateConVar( "sv_cf_blacklist", "", FCVAR_ARCHIVE, "List of bad countries. Example: 'ru, us, fr' or 'ru' :)" ):GetString() )
    cvars_AddChangeCallback( "sv_cf_blacklist", function( name, old, new ) blacklist = FormatCountries( new ) end, script_name )

    function IsAllowedCountry( country, invert )
        if (invert) then
            return not (blacklist[ country ] or false)
        end

        return blacklist[ country ] or false
    end

    concommand.Add( "view_cf_blacklist", function( ply )
        if IsValid( ply ) then
            if ply:IsSuperAdmin() then
                ply:ChatPrint( util.TableToJSON( blacklist, true ) )
                return
            end

            ply:Kick( "Nope" )

            return
        end

        MsgN( util.TableToJSON( blacklist, true ) )
    end)

end

local ip_cache = {}
local blocked_steamids = {}

do

    local kick_reason = CreateConVar( "sv_cf_reason", "Your country is blocked, from joining in this server.", FCVAR_ARCHIVE, "Reason for kicked players." ):GetString()
    cvars_AddChangeCallback( "sv_cf_reason", function( name, old, new ) kick_reason = new end, script_name )

    local kick_on_failure = CreateConVar( "sv_cf_kick_on_failure", "0", FCVAR_ARCHIVE, "Kick player if request failed.", 0, 1 ):GetBool()
    cvars_AddChangeCallback( "sv_cf_kick_on_failure", function( name, old, new ) kick_on_failure = tobool( new ) end, script_name )

    local steamid_blacklist = CreateConVar( "sv_cf_steamid_blacklist", "1", FCVAR_ARCHIVE, "Storage all blocked steamid's for prevent bypass kick.", 0, 1 ):GetBool()
    cvars_AddChangeCallback( "sv_cf_steamid_blacklist", function( name, old, new ) steamid_blacklist = tobool( new ) end, script_name )

    local blacklist_is_whitelist = CreateConVar( "sv_cf_blacklist_is_whitelist", "0", FCVAR_ARCHIVE, "Invert blacklist to whitelist, only countries in the list can connect.", 0, 1 ):GetBool()
    cvars_AddChangeCallback( "sv_cf_blacklist_is_whitelist", function( name, old, new ) blacklist_is_whitelist = tobool( new ) end, script_name )

    do

        local game_GetIPAddress = game.GetIPAddress
        local util_JSONToTable = util.JSONToTable
        local http_Fetch = http.Fetch
        local istable = istable

        hook.Add("CheckPassword", script_name, function( steamid64, ip, sv_pass, cl_pass, name )
            if (steamid_blacklist) and blocked_steamids[ steamid64 ] then
                return true, kick_reason
            end

            local country = ip_cache[ ip ]
            if (country) then
                return IsAllowedCountry( country, blacklist_is_whitelist ), kick_reason
            end

            http_Fetch( "http://ip-api.com/json/" .. ( (game_GetIPAddress() == ip) and ip or "") .. "?fields=16386", function( body, size, headers, code )
                if (code == 200) and (size < 100) then
                    local data = util_JSONToTable( body )
                    if istable( data ) then
                        if (data.status == "success") then
                            local country = data.countryCode
                            if isstring( country ) then
                                ip_cache[ ip ] = country:lower()

                                if IsAllowedCountry( country, blacklist_is_whitelist ) then return end
                                blocked_steamids[ steamid64 ] = true
                                game.KickID64( steamid64, kick_reason )

                                return
                            end
                        end
                    end
                end

                if (kick_on_failure) then
                    game.KickID64( steamid64, kick_reason )
                end
            end, function( err )
                if (kick_on_failure) then
                    game.KickID64( steamid64, kick_reason )
                end
            end)
        end)

    end

end