/*
 * Copyright (c) 2003-2015 GameDuell GmbH, All Rights Reserved
 * This document is strictly confidential and sole property of GameDuell GmbH, Berlin, Germany
 */

package duell;

#if ios
import ios_appdelegate.IOSAppDelegate;
#end
#if android
import android_appdelegate.AndroidAppDelegate;
#end
#if flash
import flash_appdelegate.FlashAppDelegate;
#end
#if html5
import html5_appdelegate.HTML5AppDelegate;
#end
import input.KeyboardEventData;
import msignal.Signal;

import graphics.Graphics;

import runloop.RunLoop;
import runloop.MainRunLoop;
import runloop.Timer;

import logger.Logger;

import filesystem.FileSystem;
import filesystem.StaticAssetList;

import types.Vector2;

import input.VirtualInputManager;
import input.Touch;
import input.MouseButton;
import input.MouseButtonState;
import input.MouseButtonEventData;
import input.MouseMovementEventData;


#if (html5 || flash)
import input.KeyboardManager;
import input.MouseManager;
#end

#if (ios || android || html5)
import input.TouchManager;
#end

class DuellKit
{
	private static inline var INITIAL_TIMER_FRAME_MAX_DELTA = 1.0/15.0;
	private static inline var INITIAL_TIMER_FRAME_MIN_DELTA = 1.0/60.0;

    /// callbacks
    public var onEnterFrame(default, null): Signal0 = new Signal0();
    public var onRender(default, null): Signal0 = new Signal0();
    public var onExitFrame(default, null): Signal0 = new Signal0();

	public var onTouches(default, null): Signal1<Array<Touch>> = new Signal1();

	public var onMouseButtonEvent(default, null): Signal1<MouseButtonEventData> = new Signal1();
	public var onMouseMovementEvent(default, null): Signal1<MouseMovementEventData> = new Signal1();
	public var mouseState(get, null): Map<MouseButton, MouseButtonState>;
	public var mousePosition(get, null): Vector2;

	public var onKeyboardEvent(default, null): Signal1<KeyboardEventData> = new Signal1();

    /**
      * Dispatched when the app is about to enter into the background.
    **/
    public var onApplicationWillEnterBackground(default, null): Signal0 = new Signal0();

    /**
      * Dispatched when the app is about to come back to foreground.
    **/
    public var onApplicationWillEnterForeground(default, null): Signal0 = new Signal0();

    /**
      * Dispatched when the app is about to terminate. Depending on the platform this might not be called at all.
      *
      * App Termination:
      *
      * Apps must be prepared for termination to happen at any time and should not wait
      * to save user data or perform other critical tasks.
      * System-initiated termination is a normal part of an app’s life cycle.
      * The system usually terminates apps so that it can reclaim memory and make room for
      * other apps being launched by the user, but the system may also terminate apps
      * that are misbehaving or not responding to events in a timely manner.
    **/
    public var onApplicationWillTerminate(default, null): Signal0 = new Signal0();

    // TODO implement
   // public var onApplicationDidReceiveMemoryWarning(default, null): Signal0 = new Signal0();

    public var onError(default, null): Signal1<Dynamic> = new Signal1();

    public var onScreenSizeChanged(default, null): Signal0 = new Signal0();

	public var screenWidth(default, null): Float;
	public var screenHeight(default, null): Float;

	/// time
    public var mainTimer(default, null): Timer;
    public var frameDelta(get, null): Float;
	public var frameStartTime(get, null): Float;
	public var time(get, null): Float; 

	/// runloop
	public var loopTheMainLoopOnRender: Bool = true;
	public var mainLoop : MainRunLoop = RunLoop.getMainLoop();

	/// assets
	public var staticAssetList(default, null) : Array<String> = StaticAssetList.list;

	static private var kitInstance : DuellKit;

	private function new(): Void
	{
        initAppDelegate();

        mainTimer = new Timer(1);
        mainTimer.frameDeltaMax = INITIAL_TIMER_FRAME_MAX_DELTA;
        mainTimer.frameDeltaMin = INITIAL_TIMER_FRAME_MIN_DELTA;        

        onError.add(function (e) {

	        if(onError.numListeners == 1) /// only this
	        {
	        	Logger.print("Error: " + e + "\n");
                Logger.print("Stacktrace:" + "\n");
                Logger.print(haxe.CallStack.exceptionStack().join("\n"));
                Logger.print("===========" + "\n");
	            throw e;
	        }

        });
    }

    private function initAppDelegate()
    {
#if ios
        IOSAppDelegate.instance().onWillResignActive.add(onApplicationWillEnterBackground.dispatch);
        IOSAppDelegate.instance().onWillEnterForeground.add(onApplicationWillEnterForeground.dispatch);
        IOSAppDelegate.instance().onWillTerminate.add(onApplicationWillTerminate.dispatch);
#end

#if android
        AndroidAppDelegate.instance().onPause.add(onApplicationWillEnterBackground.dispatch);
        AndroidAppDelegate.instance().onResume.add(onApplicationWillEnterForeground.dispatch);
        AndroidAppDelegate.instance().onDestroy.add(onApplicationWillTerminate.dispatch);
#end

#if flash
        FlashAppDelegate.instance().onDeactivate.add(onApplicationWillEnterBackground.dispatch);
        FlashAppDelegate.instance().onActivate.add(onApplicationWillEnterForeground.dispatch);
        FlashAppDelegate.instance().onRemoveFromStage.add(onApplicationWillTerminate.dispatch);
#end

#if html5
        HTML5AppDelegate.instance().onBlur.add(onApplicationWillEnterBackground.dispatch);
        HTML5AppDelegate.instance().onFocus.add(onApplicationWillEnterForeground.dispatch);
        HTML5AppDelegate.instance().onUnload.add(onApplicationWillTerminate.dispatch);
#end
    }

	static public inline function instance(): DuellKit
	{
		return kitInstance;
	}

    private static var callbackAfterInitializing: Void -> Void;
	public static function initialize(finishedCallback: Void -> Void): Void
	{
        callbackAfterInitializing = finishedCallback;

		kitInstance = new DuellKit();

		/// TODO REFACTOR WITH TASKS
	    Graphics.initialize(function () {

			kitInstance.screenWidth = Graphics.instance().mainContextWidth;
			kitInstance.screenHeight = Graphics.instance().mainContextHeight;
	    	Graphics.instance().onMainContextSizeChanged.add(kitInstance.performOnScreenSizeChanged);
	    	Graphics.instance().onRender.add(kitInstance.performPreInitializeOnRender);

	    	kitInstance.initTheOtherSystems();
	    });
	}

    @:deprecated('Use logger.Logger.print() instead from the duelllib "Logger"')
    public static function print(v: Dynamic, ?pos: haxe.PosInfos)
    {
        Logger.print(v, pos);
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


		/// KEYBOARD
		#if (flash || html5)
		taskArray.push(function() KeyboardManager.initialize(runAnotherInit));

		taskArray.push(function()
		{
			KeyboardManager.instance().getMainKeyboard().onKeyboardEvent.add(performOnKeyboardEvent);
			runAnotherInit();
		});

		#end /// keyboard


        /// VIRTUAL INPUT
        taskArray.push(function() VirtualInputManager.initialize(runAnotherInit));



		/// finalize with calling the duell kit finished initializing
		taskArray.push(initializeFinished);

		/// just runs the first one
		runAnotherInit();
	}

	private function initializeFinished()
	{
		mainTimer.start();
		callbackAfterInitializing();

	    Graphics.instance().onRender.remove(kitInstance.performPreInitializeOnRender);
	    Graphics.instance().onRender.add(kitInstance.performOnRender);
		callbackAfterInitializing = null;
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

	private function performPreInitializeOnRender(): Void
	{
		try
		{
            // Mainloop, runs the timers, delays and async executions
            mainLoop.loopMainLoop();
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
            // Input Processing in here
            onEnterFrame.dispatch();

            if (loopTheMainLoopOnRender)
            {
	            // Mainloop, runs the timers, delays and async executions
	            mainLoop.loopMainLoop();
            }

            // Rendering
            Graphics.instance().clearAllBuffers();
			onRender.dispatch();
			Graphics.instance().present();

            onExitFrame.dispatch();
		}
		catch(e : Dynamic)
		{
			onError.dispatch(e);
		}
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

	private function performOnKeyboardEvent(event: KeyboardEventData): Void
	{
		try
		{
			onKeyboardEvent.dispatch(event);
		}
		catch(e : Dynamic)
		{
			onError.dispatch(e);
		}
	}

	private function get_mousePosition(): Vector2
	{
		#if (html5 || flash)
			return MouseManager.instance().getMainMouse().screenPosition;
		#else
		    return null;
		#end
    }


	private function get_mouseState(): Map<MouseButton, MouseButtonState>
	{
		#if (html5 || flash)
			return MouseManager.instance().getMainMouse().state;
		#else
		    return null;
		#end
    }

    private function get_frameDelta(): Float
    {
    	return mainTimer.frameDelta;
    }

    private function get_frameStartTime(): Float
    {
    	return mainTimer.frameStartTime;
    }

    private function get_time(): Float
    {
    	return mainTimer.time;
    }
}


