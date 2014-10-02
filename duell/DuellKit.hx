package duell;

import msignal.Signal;

import graphics.Graphics;

import asyncrunner.Task;
import asyncrunner.RunLoop;
import asyncrunner.MainRunLoop;
import asyncrunner.FunctionTask;
import asyncrunner.SequentialTaskGroup;

import filesystem.FileSystem;
import filesystem.StaticAssetList;

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
	public var onRender(default, null) : Signal0 = new Signal0();
	public var onTouches(default, null) : Signal1<Array<Touch>> = new Signal1();

	public var onMouseButtonEvent(default, null) : Signal1<MouseButtonEventData> = new Signal1();
	public var onMouseMovementEvent(default, null) : Signal1<MouseMovementEventData> = new Signal1();
	public var mouseState(get, null) : Map<MouseButton, MouseButtonState>;
	public var mousePosition(get, null) : Vector2;

	//public var onMemoryWarning(default, null) : Signal0 = new Signal0();

    public var onError(default, null) : Signal1<Dynamic> = new Signal1();

    public var onScreenSizeChanged(default, null) : Signal0 = new Signal0();

	public var screenWidth(default, null) : Float;
	public var screenHeight(default, null) : Float;

	/// time
	public var frameStartTime(default, null) : Float;
	public var frameDelta(default, null) : Float;

	/// assets
	public var staticAssetList(default, null) : Array<String> = StaticAssetList.list;

	static private var kitInstance : DuellKit;
	private var mainLoop : MainRunLoop = RunLoop.getMainLoop();

	private function new() : Void 
	{
        onError.add(function (e) {

	        if(onError.numListeners == 1) /// only this
	            throw e;

        });
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

			kitInstance.screenWidth = Graphics.instance().mainContextWidth;
			kitInstance.screenHeight = Graphics.instance().mainContextHeight;
	    	Graphics.instance().onMainContextSizeChanged.add(kitInstance.performOnScreenSizeChanged);

			kitInstance.frameStartTime = Timer.stamp();
			kitInstance.frameDelta = 0;
	    	Graphics.instance().onRender.add(kitInstance.performOnRender);

	    	kitInstance.initTheOtherSystems();
	    });
	}

	private function initTheOtherSystems()
	{
		var taskArray : Array<Task> = [];

		/// FILESYSTEM
		var filesystemTask : FunctionTask = null;
		filesystemTask = new FunctionTask(function() FileSystem.initialize(filesystemTask.finishExecution), false);

		/// PUSH FILESYSTEM
		taskArray.push(filesystemTask);

		/// MOUSE
		#if (flash || html5) 

		var mouseTask : FunctionTask = null;
		mouseTask = new FunctionTask(function() MouseManager.initialize(mouseTask.finishExecution), false);

		var postMousetask = new FunctionTask(function() {
			MouseManager.instance().getMainMouse().onMovementEvent.add(performOnMouseMovementEvent);
			MouseManager.instance().getMainMouse().onButtonEvent.add(performOnMouseButtonEvent);
		});

		/// PUSH MOUSE
		taskArray.push(mouseTask);
		taskArray.push(postMousetask);

		#end /// mouse

		/// TOUCH
		#if (html5 || ios || android)

		var touchTask : FunctionTask = null;
		touchTask = new FunctionTask(function() TouchManager.initialize(touchTask.finishExecution), false);

		var postTouchtask = new FunctionTask(function() {
			TouchManager.instance().onTouches.add(performOnTouches);
		});

		/// PUSH TOUCH
		taskArray.push(touchTask);
		taskArray.push(postTouchtask);

		#end /// touch

		/// finalize with calling the duell kit finished initializing
		taskArray.push(new FunctionTask(callbackAfterInitializing));

		new SequentialTaskGroup(taskArray).execute();
	}

	private function performOnScreenSizeChanged()
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

	private function performOnRender()
	{
		try
		{
			var newCurrentTime = Timer.stamp();
			frameDelta = newCurrentTime - frameStartTime;
			frameStartTime = newCurrentTime;

	    	Graphics.instance().clearAllBuffers();
			onRender.dispatch();
			Graphics.instance().present();	

			mainLoop.loopMainLoop();
		}
		catch(e : Dynamic)
		{
			onError.dispatch(e);
		}
	}

	private function performOnMouseMovementEvent(event : MouseMovementEventData)
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

	private function performOnMouseButtonEvent(event : MouseButtonEventData)
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

	private function performOnTouches(touches : Array<Touch>)
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

	public function get_mousePosition() : Vector2
	{
		#if (html5 || flash)
			return MouseManager.instance().getMainMouse().screenPosition;
		#else
		    return null;
		#end
    }


	public function get_mouseState() : Map<MouseButton, MouseButtonState>
	{
		#if (html5 || flash)
			return MouseManager.instance().getMainMouse().state;
		#else
		    return null;
		#end
    }
}


