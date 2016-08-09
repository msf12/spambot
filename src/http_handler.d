module http_handler;

import globals,
std.stdio,
std.exception,
std.algorithm,
std.file,
std.net.curl,
std.format,
std.json;

//TODO: check for new followers!

void httptest()
{
	try
	{
		JSONValue viewers = parseJSON(getChatList());
		writeln(viewers["chatters"]);
	}
	catch(Exception e)
	{
		writeln("ERROR: Is Twitch down right now?");
	}
}

string[] getFollowers()
{
	//Get the follows object from twitch
	JSONValue followerJSONArray = parseJSON(sendAPIRequest(format("channels/%s/follows",CHAN)));
	//Isolate the JSON follows array and convert it to a D array
	JSONValue[] followers = followerJSONArray["follows"].array();
	//extract only the username strings and return them
	string[] followerStrings = new string[followers.length];
	foreach(int i,follower; followers)
	{
		followerStrings[i] = follower["display_name"].str();
	}
	return followerStrings;
}

char[] getChatList()
{
	return get(format("tmi.twitch.tv/group/user/%s/chatters",CHAN));
}

//TODO: if necessary add POST, PUT, and DELETE???
char[] sendAPIRequest(immutable string endpoint)
{
	return get(format("https://api.twitch.tv/kraken/%s?oauth_token=%s",endpoint,PASS[(countUntil(PASS,":")+1)..$]));
}