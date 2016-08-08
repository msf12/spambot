module message_handler;

import globals, memes, synchronizedQueue, spambot_util,
std.stdio,
std.concurrency,
std.algorithm,
std.json,
std.file,
std.string,
std.regex,
core.time;

void messageHandler(Tid owner, ref shared SynchronizedQueue!string messageQueue, ref shared SynchronizedQueue!string responseQueue)
{
	auto log = File("log.txt","w");

	auto filecontents = readText("blacklist.json");
	JSONValue blacklist = parseJSON(filecontents);

	//when messageHandler goes out of scope
	scope(exit)
	{
		debug.writeln("messageHandler exiting scope");
		//send a priority message to the parent thread signaling the messageHandler is exiting
		prioritySend(owner,1);
		log.close();
		debug.writeln("messageHandler complete");
		//throw new Exception("Message Handler has exited unexpectedly!");
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
			    //debug.writeln(format("(messageHandler) Message: \"%s\"\n\tUser: %s",message.text,message.user));
			    auto response = chooseResponse(message,blacklist);
			    if(response != "")
			    {
				    responseQueue.enqueue(formatOutgoingMessage(CHAN,response));
			    }
				log.writeln(format("(messageHandler) Message: \"%s\"\n\tUser: %s",message.text,message.user));
			}
		}
	}
}

string chooseResponse(ref Message message, ref JSONValue blacklist)
{
	scope(failure)
	{
		writeln("Something broke");
	}
	if(message.text[0] == '!')
	{
		runCommand(message, blacklist);
		return "";
	}
	else
	{
		//run through the blacklist to check if a message requires moderation and, if so, what action
		foreach(string phrase, action; blacklist)
		{
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
				"\nThis requires action: " ~ action.str());
				return action.str();
			}
		}
		return format("Test response for %s who said %s",message.user,message.text);
	}
}

void runCommand(ref Message message, ref JSONValue blacklist)
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
				return;
			}
			//countUntil counts from the beginning of the splice so commandEnd+1 must be manually added to the count
			auto subcommandEnd = commandEnd + 1 + countUntil(message.text[commandEnd+1..$]," ");
			auto commandType = message.text[(commandEnd+1)..subcommandEnd];
			auto args = message.text[(subcommandEnd+1)..$];
			debug.writeln("Command: \"blacklist\"\nCommand type: \"" ~ commandType ~ "\"\nArgs: \"" ~ args ~ "\"\n");

			break;
		
		/**
		 * 
		 */

		default:
	}
}