class Extension extends Julia.Extension
 implements Julia.InterestedInCommandDispatched,
            Julia.InterestedInPlayerConnected,
            HTTP.ClientOwner;

/**
 * Copyright (c) 2014 Sergei Khoroshilov <kh.sergei@gmail.com>
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import enum eClientError from HTTP.Client;

/**
 * Max length of an arbitrary lookup argument
 * @type int
 */
const MAX_ARBITRARY_ARG_LENGTH=50;


enum eRequestKey
{
    RK_KEY_HASH,        /* Last 16 characters of the md5-hex-encoded Key */
    RK_COMMAND_NAME,    /* "whois", etc */
    RK_COMMAND_ID,      /* Dispatched command unique id */
    RK_COMMAND_ARGS     /* Arguments separated by space */
};

/**
 * HTTP client instance
 * @type class'HTTP.Client'
 */
var protected HTTP.Client Client;

/**
 * List of extra commands with arbitrary arguments
 * @type array<string>
 */
var config array<string> Commands;

/**
 * Whois service URL
 * @type string
 */
var config string URL;

/**
 * Server credentials
 * @type string
 */
var config string Key;

/**
 * Indicate whether a whois query should be automatically sent upon a player connection
 * @type bool
 */
var config bool Auto;

/**
 * @return  void
 */
public function PreBeginPlay()
{
    Super.PreBeginPlay();

    if (self.URL == "")
    {
        log(self $ " has been provided with empty URL");
        self.Destroy();
    }
    else if (self.Key == "")
    {
        log(self $ " has been provided with empty key");
        self.Destroy();
    }
}

/**
 * @return  void
 */
public function BeginPlay()
{
    Super.BeginPlay();

    self.Core.RegisterInterestedInPlayerConnected(self);
    self.Client = Spawn(class'HTTP.Client');

    self.RegisterCommands();
}

/**
 * Regiser the whois command along with the commands defined in Commands list
 * 
 * @return  void
 */
protected function RegisterCommands()
{
    local int i;

    // Register the builtin whois command
    self.Core.GetDispatcher().Bind(
        "whois", self, self.Locale.Translate("WhoisCommandUsage"), self.Locale.Translate("WhoisCommandDescription")
    );
    // Register custom commands defined in the Commands list
    for (i = 0; i < self.Commands.Length; i++)
    {
        self.Core.GetDispatcher().Bind(
            self.Commands[i], self, self.Locale.Translate("CustomCommandUsage"), self.Locale.Translate("CustomCommandDescription")
        );
    }
}

/**
 * Parse command arguments and dispatch the command to a remote whois service
 * 
 * @see Julia.InterestedInCommandDispatched.OnCommandDispatched
 */
public function OnCommandDispatched(Julia.Dispatcher Dispatcher, string Name, string Id, array<string> Args, Julia.Player Player)
{
    local Julia.Player MatchedPlayer;
    local string ArgsCombined;

    // whois commands are only available to admins
    if (!Player.IsAdmin())
    {
        Dispatcher.ThrowPermissionError(Id);
        return;
    }
    ArgsCombined = class'Utils.ArrayUtils'.static.Join(Args, " ");
    // whois commands require an argument
    if (Len(ArgsCombined) == 0)
    {
        Dispatcher.ThrowUsageError(Id);
        return;
    }
    if (Name == "whois")
    {
        MatchedPlayer = self.Core.GetServer().GetPlayerByWildName(ArgsCombined);

        if (MatchedPlayer == None)
        {
            Dispatcher.ThrowError(Id, self.Locale.Translate("WhoisCommandNoMatchError"));
            return;
        }
        self.SendWhoisRequest("whois", MatchedPlayer.GetName() $ "\t" $ MatchedPlayer.GetIpAddr(), Id);
    }
    else
    {
        if (Len(ArgsCombined) > class'Extension'.const.MAX_ARBITRARY_ARG_LENGTH)
        {
            Dispatcher.ThrowError(Id, self.Locale.Translate("CustomCommandLengthError"));
            return;
        }
        self.SendWhoisRequest(Name, ArgsCombined, Id);
    }
}

/**
 * Display player whois details upon joining server
 * 
 * @see Julia.InterestedInPlayerConnected.OnPlayerConnected
 */
public function OnPlayerConnected(Julia.Player Player)
{
    // Only perform a whois lookup when a player connects midgame
    if (!self.Auto || self.Core.GetServer().GetGameState() != GAMESTATE_MidGame)
    {
        return;
    }
    self.SendWhoisRequest("whois", Player.GetName() $ "\t" $ Player.GetIpAddr(), "!");
}

/**
 * Parse a successful HTTP request in order to respond to a dispatched player command
 * 
 * @see HTTP.ClientOwner.OnRequestSuccess
 */
public function OnRequestSuccess(int StatusCode, string Response, string Hostname, int Port)
{
    local array<string> Lines;
    local string Id, Message;

    if (StatusCode == 200)
    {
        Lines = class'Utils.StringUtils'.static.Part(Response, "\n");

        if (Lines.Length > 2 && Len(Lines[0]) == 1)
        {
            // 0 - Success
            if (Lines[0] == "0")
            {
                // Id of the dispatched command
                Id = Lines[1];
                // Strip status code and id from the split response
                Lines.Remove(0, 2);
                // Then join what's left back with a \n
                Message = Left(class'Utils.ArrayUtils'.static.Join(Lines, "\n"), 512); // 512 - dont let chat overflow
                // Display to all admins
                if (Id == "!")
                {
                    class'Utils.LevelUtils'.static.TellAdmins(self.Level, Message);
                }
                else
                {
                    self.Core.GetDispatcher().Respond(Left(Id, class'Julia.Dispatcher'.const.COMMAND_ID_LENGTH), Message);
                }
                return;
            }
        }
    }
    log(self $ " received invalid response from " $ Hostname $ " (" $ StatusCode $ ":" $ Left(Response, 20) $ ")");
}

/**
 * @see HTTP.ClientOwner.OnRequestFailure
 */
public function OnRequestFailure(eClientError ErrorCode, string ErrorMessage, string Hostname, int Port)
{
    log(self $ " failed a request to " $ Hostname $ " (" $ ErrorMessage $ ")");
}

/**
 * Assemble a whois request and send it over
 * 
 * @param   string Command
 * @param   string Args
 * @param   string Id
 * @return  void
 */
protected function SendWhoisRequest(string Command, string Args, string Id)
{
    local HTTP.Message Message;

    Message = Spawn(class'Message');

    Message.AddQueryString(eRequestKey.RK_KEY_HASH, Right(ComputeMD5Checksum(self.Key), 16));
    Message.AddQueryString(eRequestKey.RK_COMMAND_NAME, Command);
    Message.AddQueryString(eRequestKey.RK_COMMAND_ID, Id);
    Message.AddQueryString(eRequestKey.RK_COMMAND_ARGS, Args);

    self.Client.Send(Message, self.URL, 'GET', self, 1);  // 1 attempt
}

event Destroyed()
{
    if (self.Client != None)
    {
        self.Client.Destroy();
        self.Client = None;
    }

    if (self.Core != None)
    {
        self.Core.GetDispatcher().UnbindAll(self);
        self.Core.UnregisterInterestedInPlayerConnected(self);
    }
    
    Super.Destroyed();
}

defaultproperties
{
    Title="Julia/Whois";
    Version="1.0.0";
    LocaleClass=class'Locale';
}

/* vim: set ft=java: */