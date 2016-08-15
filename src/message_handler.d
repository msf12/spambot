module message_handler;

import globals, synchronizedQueue, spambot_util, http_handler, trie,
std.stdio,
std.concurrency,
std.algorithm,
std.json,
std.file,
std.string,
std.regex,
std.container,
core.time;

void messageHandler(Tid owner, ref shared SynchronizedQueue!string messageQueue, ref shared SynchronizedQueue!string responseQueue)
{
	scope(failure)
	{
		writeln("Message handler thread has crashed");
	}

	auto log = File("log.txt","w");
	string filecontents;


//TODO: store the followers to a file. spawn a thread on launch to check the loaded file against the twitch API
	//get the follower list when the bot starts
	auto followers = new Trie();
	foreach(follower; getFollowers())
	{
		followers.add(follower);
	}

	//track the last time followers were checked as the API updates once every minute or so
	auto lastFollowerCheck = MonoTime.currTime();
	auto lastFollowerMessage = MonoTime.currTime();
	
	DList!string newFollowerShoutouts;
	
	debug.writeln("Current followers: " ~ followers.toString());

	foreach(string line;lines(File("blacklist.json","r")))
	{
		if(!canFind(line,"null"))
		{
			filecontents~=line;
		}
	}

	//ensure the last three characters are NOT ",\n}"
	if(filecontents.length > 4 && filecontents[$-3] == ',')
	{
		filecontents = filecontents[0..($-3)] ~ filecontents[($-2)..$];
	}

	JSONValue blacklist = parseJSON(filecontents);

	//when messageHandler goes out of scope
	scope(success)
	{
		debug.writeln("messageHandler exiting scope");
		//send a priority message to the parent thread signaling the messageHandler is exiting
		prioritySend(owner,1);
		log.close();
		saveJSON(blacklist,"blacklist.json");
		debug.writeln("messageHandler complete");
	}
	//while the program is running
	while(true)
	{
		//if this thread receives a message that the parent is exiting scope, terminate this thread
		if(receiveTimeout(dur!"hnsecs"(1),
						  (int message)
						  {
							  debug.writeln(format("int message %s received by messageHandler",message));
							  if(message == 1)
							  {
								  return true;
							  }
							  return false;
						  }))
		{
			return;
		}

		//check the queue for new messages
		if(messageQueue.length > 0)
		{
			auto messagePtr = stringToMessage(messageQueue.dequeue());
			if(messagePtr != null)
			{
			    auto message = *messagePtr;
			    debug.writeln(format("(messageHandler) Message: \"%s\"\n\tUser: %s",message.text,message.user));
			    auto response = chooseResponse(message,blacklist);
			    if(response != null)
			    {
				    responseQueue.enqueue(formatOutgoingMessage(CHAN,response));
			    }
				log.writeln(format("(messageHandler) Message: \"%s\"\n\tUser: %s",message.text,message.user));
			}
		}

		//if enough time has passed that the API may have updated the follower list
		if((MonoTime.currTime() - lastFollowerCheck).total!"seconds" > 60)
		{
			auto newFollowers = getNewFollowers(followers);

			//iterate through the new followers and queue the shoutouts to be added to responseQueue
			foreach(newFollower; newFollowers)
			{
				newFollowerShoutouts.insertBack(formatOutgoingMessage(CHAN,"Thank you so much for following, " ~ newFollower));
				//add the new follower to the trie
				followers.add(newFollower);
			}
			lastFollowerCheck = MonoTime.currTime();
		}

		//if there are new followers to shoutout and 15 seconds have passed since the last shoutout enqueue the shoutout message
		if(!newFollowerShoutouts.empty() &&
			(MonoTime.currTime() - lastFollowerMessage).total!"seconds" > 15)
		{
			responseQueue.enqueue(newFollowerShoutouts.back());
			newFollowerShoutouts.removeBack();
		}
	}
}

string chooseResponse(ref Message message, ref JSONValue blacklist)
{
	scope(failure)
	{
		writeln("chooseResponse(" ~ message.text ~ ", " ~ blacklist.toString() ~ ") failed");
	}
	if(message.text[0] == '!')
	{
		auto response = runCommand(message, blacklist);
		return response;
	}
	else
	{
		//run through the blacklist to check if a message requires moderation and, if so, what action
		foreach(string phrase, action; blacklist)
		{
			if(action.type() == JSON_TYPE.NULL)
			{
				continue;
			}
			//get the first and last character of the blacklist element
			char firstChar = phrase[0],
			lastChar = phrase[$-1];
			Regex!char blacklistedRegex;

			//blacklist elements beginning and ending with * can appear anywhere in the message
			//(ex. *hell* matches both hello and shell)
			if(firstChar == '*' && lastChar == '*')
			{
				blacklistedRegex = regex(phrase[1..($-1)]);
			}
			//blacklist elements beginning with * do not include words that start with the blacklist element
			//(ex. *hell doesn't match hello but will match shell)
			else if(firstChar == '*')
			{
				blacklistedRegex = regex(phrase[1..$] ~ r"(\W|$)");
			}
			//blacklist elements ending with * do not include words that end with the blacklist element 
			//(ex. hell* does match hello but will not match shell)
			else if(lastChar == '*')
			{
				blacklistedRegex = regex(r"(\W|^)" ~ phrase[0..($-1)]);
			}
			//blacklist elements with no * only moderate messages with the EXACT word
			//(ex. hell does not match either hello or shell)
			else
			{
				blacklistedRegex = regex(r"(\W|^)" ~ phrase ~ r"(\W|$)");
			}

			if(matchFirst(toLower(message.text), blacklistedRegex))
			{
				writeln("Moderation action required on message: " ~ message.text ~
				"\nThe message has matched blacklist item: " ~ phrase ~ 
				"\nThis requires action: " ~ format(action.str(),message.user));
				return format(action.str(),message.user);
			}
		}
		return null;//format("Test response for %s who said %s",message.user,message.text);
	}
}

string runCommand(ref Message message, ref JSONValue blacklist)
{
	debug.writeln("Command received");

	//if the command is a single word there will be no space so check for a space before isolating the command string
	auto commandEnd = canFind(message.text," ") ? countUntil(message.text," ") : message.text.length;
	auto command = message.text[1..commandEnd];

	switch(command)
	{
		/**
		 * !blacklist <command> <args>
		 * add "term:command"     -> adds "term":"command" to the blacklist JSONValue
		 * list "term"            -> lists all terms similar to "term" 
		 * search "term"          -> searches for "term" and says whether or not it appears in blacklist
		 * remove "term"          -> removes "term" from blacklist or sends error message if it doesn't exist
		 */
		case "blacklist":
			//At the moment a valid blacklist command takes one subcommand and an argument
			if(count(message.text," ") < 2)
			{
				stderr.writeln(format("ERROR: Malformed blacklist command \"%s\"",message.text));
				return null;
			}
			//countUntil counts from the beginning of the splice so commandEnd+1 must be manually added to the count
			auto subCommandEnd = commandEnd + 1 + countUntil(message.text[commandEnd+1..$]," ");
			auto subCommand = message.text[(commandEnd+1)..subCommandEnd];
			auto args = message.text[(subCommandEnd+1)..$];
			debug.writeln("Command: \"blacklist\"\nCommand type: \"" ~ subCommand ~ "\"\nArgs: \"" ~ args ~ "\"\n");

			if(args[0] != '"' || args[$-1] != '"')
			{
				stderr.writeln("ERROR: Invalid blacklist argument \"" ~ args ~ "\"");
				return null;
			}
			args = args[1..($-1)];

			switch(subCommand)
			{
				case "add":
					if(!canFind(args,":"))
					{
						stderr.writeln("ERROR: Invalid blacklist add argument - invalid argument syntax " ~ args);
						return null;
					}
					auto argsSplit = countUntil(args,":");
					blacklist[args[0..argsSplit]] = args[(argsSplit+1)..$];
					return "\"" ~ args[0..argsSplit] ~ "\" added to blacklist";
//TODO: list and search to be implemented later
				case "list":
					break;
				case "search":
					break;
				case "remove":
					if(!(args in blacklist))
					{
						stderr.writeln("ERROR: Invalid blacklist remove argument - argument not found " ~ args);
						return null;
					}
					blacklist[args] = null;
					return "\"" ~ args ~ "\" removed from blacklist";
				default:
					stderr.writeln("ERROR: Invalid blacklist subcommand \"" ~ subCommand ~ "\"");
					return null;
			}

			break;
		
		/**
		 * 
		 */

		default:
			stderr.writeln("ERROR: Invalid command string \"" ~ command ~ "\"");
	}
	return null;
}
