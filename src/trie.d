module trie;

import std.range;

class Trie
{
	private struct Node
	{
		Node[char] children;
		bool isValidString;
		alias children this;
	}

	private Node root;

	this()
	{
		root.isValidString = false;
	}
	~this()
	{
		deleteNode(root);
	}

	private void deleteNode(ref Node node)
	{
		if(node.children.length == 0)
		{
			return;
		}
		else
		{
			foreach(key, child; node)
			{
				deleteNode(child);
				node.children.remove(key);
				node.children = null;
			}
		}
	}
	
	public bool add(string data)
	{
		//pointer to the node currently being modified
		Node* currentNode = &root;

		//the current character in data being added
		char currentChar = data[0];

		//iterate backwards from the length of data until there is one character left
		for(auto i = data.length; i > 0; --i,
			//set currentNode to point to the appropriate child
			currentNode = &((*currentNode)[currentChar]),
			//set currentChar to the next character in data
			currentChar = data[data.length - i])
		{
			//if the final character of data is already in the trie
			if(currentChar in currentNode.children && i == 1)
			{
				//return true if the child was not a valid string already
				if(!((*currentNode)[currentChar].isValidString))
				{
					return (*currentNode)[currentChar].isValidString = true;
				}
				//return false if it was a valid string
				return false;
			}
			else
			{
				//if the current character from data is not in the trie
				if(!(currentChar in currentNode.children))
				{
					//add a new Node to the trie
					(*currentNode)[currentChar] = Node(null,false);
				}
				//if add is at the last character add the end of the new string and return
				if(i == 1)
				{ 
					return (*currentNode)[currentChar].isValidString = true;
				}
			}
		}
		return false;
	}

	public override string toString()
	{
		auto result = "{ ";
		auto path = "";
		toString(result,path,root);
		result = result[0..($-2)] ~ " }";
		return result;
	}

	private void toString(ref string result, ref string parentString, ref Node node)
	{
		auto childString = "";
		foreach(key,child; node.children)
		{
			childString = parentString ~ key;
			if(child.isValidString)
			{
				result ~= "\"" ~ childString ~ "\", ";
			}
			toString(result,childString,child);
		}
	}
}