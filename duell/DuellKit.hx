package duell;

import msignal.Signal;

import graphics.Graphics;

import asyncrunner.MainRunLoop;

import types.Touch;
import types.Vector2;
import types.Mouse;

import haxe.Timer;

class DuellKit
{
	/// callbacks
	public var onUpdate(default, null) : Signal1<Float>;
	public var onRender(default, null) : Signal0;
	public var onTouches(default, null) : Signal1<Array<Touch>>;
	public var onMouseButtonEvent(default, null) : Signal1<MouseButtonEvent>;
	public var onMouseMovementEvent(default, null) : Signal1<MouseMovementEvent>;
	public var mouseState(default, null) : Map<MouseButton, MouseButtonState>;
	public var mousePosition(default, null) : Vector2;

	public var onMemoryWarning(default, null) : Signal0;

    public var onError(default, null) : Signal1<Dynamic>;

    public var onScreenSizeChanged(default, null) : Signal0;

	public var screenWidth(default, null) : Float;
	public var screenHeight(default, null) : Float;

	/// time
	public var frameStartTime(default, null) : Float;
	public var frameDelta(default, null) : Float;

	/// assets
	public var staticAssetList(default, null) : Array<String>;

	static private var kitInstance : DuellKit;
	private var mainLoop : MainRunLoop;

	private function new() : Void 
	{
		onMemoryWarning = new Signal0();
		onUpdate = new Signal1();
		onRender = new Signal0();
        onScreenSizeChanged = new Signal0();
        onError = new Signal1();

        onError.add(function (e) {

	        if(onError.numListeners == 1) /// only this
	            throw e;

        });

		//#if ios
		//IOSAppDelegate.instance().onMemoryWarning.add(dispatchMemoryWarning);
		//#end

		//#if android
		//AndroidAppDelegate.instance().onLowMemory.add(dispatchMemoryWarning);
		//#end
    }


	static public inline function instance() : DuellKit
	{
		return kitInstance;
	}

	public static function initialize(finishedCallback : Void -> Void) : Void
	{
		kitInstance = new DuellKit();

	    Graphics.initialize(function () {

	    	kitInstance.mainLoop = new MainRunLoop();

	    	Graphics.instance().onRender.add(kitInstance.performRender);
	    	kitInstance.onTouches = Graphics.instance().onTouches;

			kitInstance.screenWidth = Graphics.instance().mainContextWidth;
			kitInstance.screenHeight = Graphics.instance().mainContextHeight;
	    	Graphics.instance().onMainContextSizeChanged.add(kitInstance.performScreenSizeChanged);

			kitInstance.frameStartTime = Timer.stamp();
			kitInstance.frameDelta = 0;

	    	finishedCallback();
	    });
	}

	private function performScreenSizeChanged()
	{
		screenWidth = Graphics.instance().mainContextWidth;
		screenHeight = Graphics.instance().mainContextHeight;

		onScreenSizeChanged.dispatch();
	}

	private function performRender()
	{
		var newCurrentTime = Timer.stamp();
		frameDelta = newCurrentTime - frameStartTime;
		frameStartTime = newCurrentTime;

    	Graphics.instance().clearAllBuffers();
		onRender.dispatch();
		Graphics.instance().present();	
	}

	public function loopMainLoop(time : Float) : Void
	{
		mainLoop.loopMainLoop(time);
	}

	public function exit() : Void
	{

	}
}


