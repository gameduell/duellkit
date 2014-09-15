package duell;

import msignal.Signal;

import graphics.Graphics;

import asyncrunner.MainRunLoop;

import filesystem.FileSystem;

import types.Vector2;

import input.Touch;
import input.MouseEventData;

#if (html5 || flash)
import input.MouseManager;
#end

#if (ios || android || html5)
import input.TouchManager;
#end

import haxe.Timer;

class DuellKit
{
	/// callbacks
	public var onUpdate(default, null) : Signal1<Float>;
	public var onRender(default, null) : Signal0;
	public var onTouches(default, null) : Signal1<Array<Touch>>;

	public var onMouseButtonEvent(default, null) : Signal1<MouseButtonEventData>;
	public var onMouseMovementEvent(default, null) : Signal1<MouseMovementEventData>;
	public var mouseState(default, null) : Map<MouseButton, MouseButtonState>;
	public var mousePosition(get, null) : Vector2;

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


    public static var callbackAfterInitializing : Void -> Void;
	public static function initialize(finishedCallback : Void -> Void) : Void
	{
        callbackAfterInitializing = finishedCallback;

		kitInstance = new DuellKit();

		/// TODO REFACTOR WITH TASKS
	    Graphics.initialize(function () {

	    	kitInstance.mainLoop = new MainRunLoop();

	    	Graphics.instance().onRender.add(kitInstance.performRender);

			kitInstance.screenWidth = Graphics.instance().mainContextWidth;
			kitInstance.screenHeight = Graphics.instance().mainContextHeight;
	    	Graphics.instance().onMainContextSizeChanged.add(kitInstance.performScreenSizeChanged);

			kitInstance.frameStartTime = Timer.stamp();
			kitInstance.frameDelta = 0;

			initFileSystem(afterFileSystem);
	    });
	}

    private static function initFileSystem(after : Void->Void)
    {
        FileSystem.initialize(after);
    }

    private static function afterFileSystem()
    {
        #if (flash)
                    MouseManager.initialize(function () {

                        kitInstance.onMouseMovementEvent = MouseManager.instance().getMainMouse().onMovementEvent;
                        kitInstance.onMouseButtonEvent = MouseManager.instance().getMainMouse().onButtonEvent;

                        kitInstance.onTouches = new Signal1();

                        callbackAfterInitializing();
                    });
                #elseif (ios || android)
                    TouchManager.initialize(function () {

                        kitInstance.onMouseMovementEvent = new Signal1();
                        kitInstance.onMouseButtonEvent = new Signal1();

                        kitInstance.onTouches = TouchManager.instance().onTouches;

                        callbackAfterInitializing();
                    });
                #else
                MouseManager.initialize(function () {
                    kitInstance.onMouseMovementEvent = MouseManager.instance().getMainMouse().onMovementEvent;
                    kitInstance.onMouseButtonEvent = MouseManager.instance().getMainMouse().onButtonEvent;

                    TouchManager.initialize(function () {
                        kitInstance.onTouches = TouchManager.instance().onTouches;
                        callbackAfterInitializing();
                    });
                });
        #end
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

	public function get_mousePosition() : Vector2
	{
		#if (html5 || flash)
			mousePosition = MouseManager.instance().getMainMouse().screenPosition;
			return mousePosition;
		#else
		    return null;
		#end
    }

	public function exit() : Void
	{

	}
}


