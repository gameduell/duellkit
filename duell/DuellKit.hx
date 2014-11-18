package duell;

import msignal.Signal;

import graphics.Graphics;

import runloop.RunLoop;
import runloop.MainRunLoop;

import filesystem.FileSystem;
import filesystem.StaticAssetList;

import types.Vector2;

import input.Touch;
import input.MouseButton;
import input.MouseButtonState;
import input.MouseButtonEventData;
import input.MouseMovementEventData;

#if (html5 || flash)
import input.MouseManager;
#end

#if (ios || android || html5)
import input.TouchManager;
#end

import haxe.Timer;

@:access(duell.DuellTimer)
class DuellKit
{
     ///static
    #if flash
        static var tf : flash.text.TextField = null;
    #end

    /// callbacks
    public var onEnterFrame(default, null): Signal0 = new Signal0();
    public var onRender(default, null): Signal0 = new Signal0();
    public var onExitFrame(default, null): Signal0 = new Signal0();

	public var onTouches(default, null): Signal1<Array<Touch>> = new Signal1();

	public var onMouseButtonEvent(default, null): Signal1<MouseButtonEventData> = new Signal1();
	public var onMouseMovementEvent(default, null): Signal1<MouseMovementEventData> = new Signal1();
	public var mouseState(get, null): Map<MouseButton, MouseButtonState>;
	public var mousePosition(get, null): Vector2;

	//public var onMemoryWarning(default, null): Signal0 = new Signal0();

    public var onError(default, null): Signal1<Dynamic> = new Signal1();

    public var onScreenSizeChanged(default, null): Signal0 = new Signal0();

	public var screenWidth(default, null): Float;
	public var screenHeight(default, null): Float;

	/// time
    public var mainTimer(default, null): DuellTimer;
    public var frameDelta(default, null): Float;
	public var frameStartTime(default, null): Float;
    inline static private var frameDeltaMax: Float = 1.0/15.0;
    inline static private var frameDeltaMin: Float = 1.0/60.0;

	/// assets
	public var staticAssetList(default, null) : Array<String> = StaticAssetList.list;

	static private var kitInstance : DuellKit;
	private var mainLoop : MainRunLoop = RunLoop.getMainLoop();

	private function new(): Void
	{
        mainTimer = new DuellTimer(1);

        onError.add(function (e) {

	        if(onError.numListeners == 1) /// only this
	            throw e;

        });
    }

	static public inline function instance(): DuellKit
	{
		return kitInstance;
	}


    public static var callbackAfterInitializing: Void -> Void;
	public static function initialize(finishedCallback: Void -> Void): Void
	{
        callbackAfterInitializing = finishedCallback;

		kitInstance = new DuellKit();

		/// TODO REFACTOR WITH TASKS
	    Graphics.initialize(function () {

			kitInstance.screenWidth = Graphics.instance().mainContextWidth;
			kitInstance.screenHeight = Graphics.instance().mainContextHeight;
	    	Graphics.instance().onMainContextSizeChanged.add(kitInstance.performOnScreenSizeChanged);

            kitInstance.frameDelta = 0.0;
			kitInstance.frameStartTime = Timer.stamp();
	    	Graphics.instance().onRender.add(kitInstance.performOnRender);

	    	kitInstance.initTheOtherSystems();
	    });
	}
    static public dynamic function print(v: Dynamic,  ?pos: haxe.PosInfos = null) untyped
    {
        #if flash
            tf = flash.Boot.getTrace();
			var s = flash.Boot.__string_rec(v,"");
			tf.text +=s;
		#elseif neko
			__dollar__print(v);
		#elseif php
			php.Lib.print(v);
		#elseif cpp
			cpp.Lib.print(v);
		#elseif js
			var msg = js.Boot.__string_rec(v,"");
			var d;
            if( __js__("typeof")(document) != "undefined"
                    && (d = document.getElementById("haxe:trace")) != null ) {
                msg = msg.split("\n").join("<br/>");
                d.innerHTML += StringTools.htmlEscape(msg)+"<br/>";
            }
			else if (  __js__("typeof process") != "undefined"
					&& __js__("process").stdout != null
					&& __js__("process").stdout.write != null)
				__js__("process").stdout.write(msg); // node
			else if (  __js__("typeof console") != "undefined"
					&& __js__("console").log != null )
				__js__("console").log(msg); // document-less js (which may include a line break)

		#elseif cs
			cs.system.Console.Write(v);
		#elseif java
			var str:String = v;
			untyped __java__("java.lang.System.out.print(str)");
		#end
    }

	private function initTheOtherSystems(): Void
	{
		var taskArray : Array<Void->Void> = [];

		var runAnotherInit = function()
		{
			if (taskArray.length > 0)
			{
				RunLoop.getMainLoop().queue(taskArray.shift(), PriorityASAP);
			}
		}

		/// FILESYSTEM
		taskArray.push(function() FileSystem.initialize(runAnotherInit));

		/// MOUSE
		#if (flash || html5) 

		taskArray.push(function() MouseManager.initialize(runAnotherInit));

		taskArray.push(function() {
			MouseManager.instance().getMainMouse().onMovementEvent.add(performOnMouseMovementEvent);
			MouseManager.instance().getMainMouse().onButtonEvent.add(performOnMouseButtonEvent);
			runAnotherInit();
		});

		#end /// mouse

		/// TOUCH
		#if (html5 || ios || android)

		taskArray.push(function() TouchManager.initialize(runAnotherInit));

		taskArray.push(function() {
			TouchManager.instance().onTouches.add(performOnTouches);
			runAnotherInit();
		});

		#end /// touch

		/// finalize with calling the duell kit finished initializing
		taskArray.push(callbackAfterInitializing);

		/// just runs the first one
		runAnotherInit();
	}

	private function performOnScreenSizeChanged(): Void
	{
		try
		{
			screenWidth = Graphics.instance().mainContextWidth;
			screenHeight = Graphics.instance().mainContextHeight;

			onScreenSizeChanged.dispatch();
		}
		catch(e : Dynamic)
		{
			onError.dispatch(e);
		}
	}

    // Display Sync
	private function performOnRender(): Void
	{
		try
		{
            calculateDeltaTime();

            // Input Processing in here
            onEnterFrame.dispatch();

            // Tick main timer for update
            mainTimer.tick(frameDelta);

            // Rendering
            Graphics.instance().clearAllBuffers();
			onRender.dispatch();
			Graphics.instance().present();

            onExitFrame.dispatch();

            // Mainloop
            mainLoop.loopMainLoop();
		}
		catch(e : Dynamic)
		{
			onError.dispatch(e);
		}
	}

    private function calculateDeltaTime(): Void
    {
        var newCurrentTime = Timer.stamp();
        frameDelta = newCurrentTime - frameStartTime;
        frameStartTime = newCurrentTime;

        frameDelta = Math.min(frameDelta, frameDeltaMax);
        frameDelta = Math.max(frameDelta, frameDeltaMin);
    }

	private function performOnMouseMovementEvent(event: MouseMovementEventData): Void
	{
		try
		{
			onMouseMovementEvent.dispatch(event);
		}
		catch(e : Dynamic)
		{
			onError.dispatch(e);
		}
	}

	private function performOnMouseButtonEvent(event: MouseButtonEventData): Void
	{
		try
		{
			onMouseButtonEvent.dispatch(event);
		}
		catch(e : Dynamic)
		{
			onError.dispatch(e);
		}
	}

	private function performOnTouches(touches: Array<Touch>): Void
	{
		try
		{
			onTouches.dispatch(touches);
		}
		catch(e : Dynamic)
		{
			onError.dispatch(e);
		}

	}

	public function get_mousePosition(): Vector2
	{
		#if (html5 || flash)
			return MouseManager.instance().getMainMouse().screenPosition;
		#else
		    return null;
		#end
    }


	public function get_mouseState(): Map<MouseButton, MouseButtonState>
	{
		#if (html5 || flash)
			return MouseManager.instance().getMainMouse().state;
		#else
		    return null;
		#end
    }
}


