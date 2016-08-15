module http_handler;

import globals, trie,
std.stdio,
std.exception,
std.algorithm,
std.file,
std.net.curl,
std.format,
std.json,
std.datetime;
import requests;

void httptest()
{
	StopWatch sw;
	auto rq = Request();
	sw.start();
	writeln(sw.peek().msecs());
	get(format("https://api.twitch.tv/kraken/channels/dumj01/follows?oauth_token=%s%s",PASS[6..$],"&limit=100"));
	writeln(sw.peek().msecs());
	get(format("https://api.twitch.tv/kraken/channels/usernameop/follows?oauth_token=%s%s",PASS[6..$],"&limit=100"));
	writeln(sw.peek().msecs());
	get(format("https://api.twitch.tv/kraken/channels/lobrocop/follows?oauth_token=%s%s",PASS[6..$],"&limit=100"));
	writeln(sw.peek().msecs());
	get(format("https://api.twitch.tv/kraken/channels/jents217/follows?oauth_token=%s%s",PASS[6..$],"&limit=100"));
	writeln(sw.peek().msecs());
	rq.get(format("https://api.twitch.tv/kraken/channels/dumj01/follows?oauth_token=%s%s",PASS[6..$],"&limit=100"));
	writeln(sw.peek().msecs());
	rq.get(format("https://api.twitch.tv/kraken/channels/usernameop/follows?oauth_token=%s%s",PASS[6..$],"&limit=100"));
	writeln(sw.peek().msecs());
	rq.get(format("https://api.twitch.tv/kraken/channels/lobrocop/follows?oauth_token=%s%s",PASS[6..$],"&limit=100"));
	writeln(sw.peek().msecs());
	rq.get(format("https://api.twitch.tv/kraken/channels/jents217/follows?oauth_token=%s%s",PASS[6..$],"&limit=100"));
	writeln(sw.peek().msecs());
	sw.stop();

	//try
	//{
	//	JSONValue viewers = parseJSON(getChatList());
	//	writeln(viewers["chatters"]);
	//}
	//catch(Exception e)
	//{
	//	writeln("ERROR: Is Twitch down right now?");
	//}
}

string[] getFollowers()
{
	StopWatch sw;
	sw.start();
	write("Start: ");
	writeln(sw.peek().msecs());
	//Get the follows object from twitch
	JSONValue followerJSONArray = parseJSON(sendAPIRequest(format("channels/%s/follows",CHAN),"&limit=100"));
	write("First API request: ");
	writeln(sw.peek().msecs());
	auto followerCount = followerJSONArray["_total"].integer();

	//Initialize a string[] to return the usernames of all followers
	string[] followerStrings = new string[followerJSONArray["_total"].integer()];
	JSONValue[] followerArray;

	for(int i = 0; i < followerCount; i += 100)
	{
		//Isolate the JSON follows array and convert it to a D array
		write("Loop: ");
		writeln(i/100);
		write("Time: ");
		writeln(sw.peek().msecs());
		followerArray = followerJSONArray["follows"].array();

		foreach(int j,follower; followerArray)
		{
			followerStrings[i+j] = follower["user"]["display_name"].str();
		}
		followerJSONArray = parseJSON(sendAPIRequest(format("channels/%s/follows",CHAN),
			"&limit=100&cursor=" ~ followerJSONArray["_cursor"].str()));
	}
	sw.stop();
	write("End: ");
	writeln(sw.peek().msecs());

	return followerStrings;
}


//TODO: this will break if the streamer has 0 followers
string[] getNewFollowers(ref Trie followers)
{
	//get the first page of followers
	JSONValue followerJSONArray = parseJSON(sendAPIRequest(format("channels/%s/follows",CHAN),"&limit=100"));
	string[] newFollowers = null;
	JSONValue[] followerArray;

	while(true)
	{
		//create the array of follower JSON objects from the API response
		followerArray = followerJSONArray["follows"].array();

		//for every follower object attempt to add it to the followers Trie
		//if this succeeds the follower is new and should be added to the newFollowers array
		//if it fails the search has reached the end of the new followers and should return
		foreach(int i,follower; followerArray)
		{
			if(!followers.add(follower["user"]["display_name"].str()))
			{
				return newFollowers;
			}
			else
			{
				newFollowers ~= follower["user"]["display_name"].str();
			}
		}
		followerJSONArray = parseJSON(sendAPIRequest(format("channels/%s/follows",CHAN),
			"&limit=100&cursor=" ~ followerJSONArray["_cursor"].str()));
	}
}

char[] getChatList()
{
	return get(format("tmi.twitch.tv/group/user/%s/chatters",CHAN));
}

//TODO: if necessary add POST, PUT, and DELETE???
/**
 * endpoint - API endpoint
 * @type {immutable string}
 * args - string of additional query parameters in the form "&param1&param..."
 * @type {immutable string}
 */
Buffer!ubyte sendAPIRequest(immutable string endpoint, immutable string args = "")
{
	static auto rq = Request();
	scope(failure)
	{
		writeln("get(" ~ format("https://api.twitch.tv/kraken/%s?oauth_token=%s%s",endpoint,PASS[6..$],args) ~ ") failed");
	}
	return rq.get(format("https://api.twitch.tv/kraken/%s?oauth_token=%s%s",endpoint,PASS[6..$],args)).responseBody();
}