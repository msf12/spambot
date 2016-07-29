module message_handler;

import globals, memes, synchronizedQueue;
import std.stdio, std.utf, std.format, std.concurrency, std.algorithm;
import core.time;

struct Message
{
	string user;
	string text;
	string tags;
	//string time;
}

void messageHandler(Tid owner, ref shared SynchronizedQueue!string messageQueue, ref shared SynchronizedQueue!string responseQueue)
{
	auto log = File("log.txt","w");

	//when messageHandler goes out of scope
	scope(exit)
	{
		debug.writeln("messageHandler exiting scope");
		//send a priority message to the parent thread signaling the messageHandler is exiting
		prioritySend(owner,1);
		log.close();
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
			    //debug.writeln(format("(messageHandler) Message: \"%s\"\n\tUser: %s",message.text,message.user));
			    auto response = chooseResponse(message);
			    responseQueue.enqueue(formatOutgoingMessage(response));
				log.writeln(format("(messageHandler) Message: \"%s\"\n\tUser: %s",message.text,message.user));
			}
		}
	}
}

Message* stringToMessage(string rawmessage)
{
	Message* newMessage;
	//debug.writeln(format("String to message: %s",rawmessage));
	if(canFind(rawmessage,"PRIVMSG"))
	{
		//all user messages start with a tag string that begins with @
		if(rawmessage[0] == '@')
		{
			//countUntil returns the index of the space so the username is 2 indexes farther in
			auto tagend = countUntil(rawmessage,' ')+2;
			//new Message(username,message,tags)
			newMessage = new Message(rawmessage[tagend..countUntil(rawmessage,'!')],
									 //index of username + distance from there to the colon + 1 is where the message starts
									 rawmessage[(tagend + countUntil(rawmessage[tagend..$],':') + 1)..$],
									 //tagend includes an extraneous space and colon
									 rawmessage[0..(tagend-2)]);
			if(canFind(newMessage.text,'\x01'))
			{
				//messages that start with /me are formatted as \x01ACTION message\x01 where \x01 is a single unicode char
				//thus starting at the ninth character starts where the actual message begins
				newMessage.text = "/me " ~ newMessage.text[8..($-1)];
			}
		}
		//else it's a twitchnotify system PRIVMSG
		else
		{
			newMessage = new Message(rawmessage[(countUntil(rawmessage[1..$],':')+1)..$],
									 rawmessage[0..countUntil(rawmessage,'!')]);
		}
	}
	else
	{
		return null;
	}
	return newMessage;
}

string chooseResponse(ref Message message)
{
	if(message.text[0] == '!')
	{
		runCommand(message);
	}
	else
	{

	}
	return format("Test response for %s who said %s",message.user,message.text);
}

void runCommand(ref Message message)
{

}

//formatOutgoingMessage takes a string message and returns the full irc message to be sent
string formatOutgoingMessage(string message)
{
	return format("PRIVMSG #%s :%s\r\n",CHAN,message);
}