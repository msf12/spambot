module synchronizedQueue;

import core.sync.mutex, core.atomic;

shared class SynchronizedQueue(T)
{
	private shared struct Node(T)
	{
		T data;
		Node* next;
	}

	private __gshared Mutex headaccess;
	private Node!T* head, tail;
	private size_t size;

	this()
	{
		head = null;
		tail = null;
		size = 0;
		headaccess = new Mutex();
	}
	~this()
	{
		while(head != tail)
		{
			auto temp = tail;
			tail = tail.next;
			temp = null;
		}
		head = null;
		tail = null;
	}

	//This queue is unusual because it is reverse-linked
	//the queue is formatted as tail->Node->Node->Node->head
	public bool enqueue(T data)
	{
		headaccess.lock();
		scope(exit)
		{
			headaccess.unlock();
		}
		switch(size)
		{
			case 0:
				head = cast(shared)new Node!T(data,null);
				tail = head;
				break;
			case 1:
				head = cast(shared)new Node!T(data,null);
				tail.next = head;
				break;
			default:
				head.next = cast(shared)new Node!T(data,null);
				head = head.next;
		}
		atomicOp!"+="(size,1);
		return true;
	}
	
	public T dequeue()
	{
		T returnData;
		if(size < 2)
		{
			if(size == 0)
			{
				return null;
			}
			headaccess.lock();
			scope(exit)
			{
				headaccess.unlock();
			}
			returnData = tail.data;
			tail = null;
			head = null;
		}
		else
		{
			returnData = tail.data;
			tail = tail.next;
		}
		atomicOp!"-="(size,1);
		return returnData;
	}

	public size_t length()
	{
		return size;
	}

}