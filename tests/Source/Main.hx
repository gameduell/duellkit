import duell.DuellKit;

class Main
{
	static function main() : Void 
	{
		DuellKit.initialize(afterInitialize);
	}

	static function afterInitialize()
	{
		trace("Start after initialize");

        DuellKit.instance().onApplicationWillEnterBackground.add(function(){trace("DuellKit - Application Will Enter Background");});
        DuellKit.instance().onApplicationWillEnterForeground.add(function(){trace("DuellKit - Application Will Enter Foreground");});
        DuellKit.instance().onApplicationWillTerminate.add(function(){trace("DuellKit - Application Will Terminate");});
	}
}