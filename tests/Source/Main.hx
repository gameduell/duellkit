import duell.DuellKit;

class Main
{
	static function main() : Void 
	{
		DuellKit.initialize(afterInitialize);
	}

	static function afterInitialize()
	{
		trace("Rock");
	}
}