module http_handler;

import globals,
std.stdio,
std.exception,
std.file,
std.net.curl,
std.format,
std.json;

void httptest()
{
	try
	{
		JSONValue viewers = parseJSON(get(format("tmi.twitch.tv/group/user/%s/chatters",CHAN)));
		writeln(viewers["chatters"]);
	}
	catch(Exception e)
	{
		writeln("ERROR: Is Twitch down right now?");
	}
}