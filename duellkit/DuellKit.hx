/*
 * Copyright (c) 2003-2015, GameDuell GmbH
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

package duellkit;

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

#if (html5 || ios || tvos || android)
import gl.GLContext;
#else
import flash.display3D.Context3DClearMask;
import flash.errors.Error;
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.display.Stage3D;
import flash.display.Stage;
import flash.display.StageScaleMode;
import flash.display.StageAlign;
#end

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

	/// graphics
	public var clearAndPresentDefaultBuffer: Bool = true;

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

				#if cpp
				cpp.Lib.rethrow(e);
				#else
	            throw e;
				#end
	        }

        });
    }

    private function initAppDelegate()
    {
#if ios
		IOSAppDelegate.instance().onWillEnterBackground.add(onApplicationWillEnterBackground.dispatch);
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

		#if (html5 || ios || tvos || android)

		GLContext.setupMainContext(function () {

			kitInstance.screenWidth = GLContext.getMainContext().contextWidth;
			kitInstance.screenHeight = GLContext.getMainContext().contextHeight;
	    	GLContext.getMainContext().onContextSizeChanged.add(kitInstance.performOnScreenSizeChanged);
	    	GLContext.onRenderOnMainContext.add(kitInstance.performPreInitializeOnRender);

	    	kitInstance.initTheOtherSystems();
		});

		#else /// flash

		var stage:Stage = flash.Lib.current.stage;
		var stage3D : Stage3D = stage.stage3Ds[0];

		stage.align = StageAlign.TOP_LEFT;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.frameRate = 60;

		var onErrorFunction =  function(event: Event) kitInstance.onError.dispatch(event);
		var onContext3DCreateFunction = function (event: Event)
	    {
	        var stage:Stage = flash.Lib.current.stage;
	        var stage3D : Stage3D = stage.stage3Ds[0];
	        stage3D.context3D.configureBackBuffer(stage.stageWidth, stage.stageHeight, 2, true, false);

			kitInstance.screenWidth = stage.stageWidth;
			kitInstance.screenHeight = stage.stageHeight;

	        flash.Lib.current.stage.addEventListener(Event.ENTER_FRAME, kitInstance.performPreInitializeOnRenderFlash);

	    	kitInstance.initTheOtherSystems();
	    };

		stage3D.addEventListener( ErrorEvent.ERROR, onErrorFunction);

		stage3D.addEventListener(Event.CONTEXT3D_CREATE, onContext3DCreateFunction);

		stage.addEventListener(Event.RESIZE, kitInstance.performOnScreenSizeChangedFlash);

		flash.Lib.current.addEventListener(Event.REMOVED_FROM_STAGE, function (event: Event)
	    {
	        var stage:Stage = flash.Lib.current.stage;
	        var stage3D : Stage3D = stage.stage3Ds[0];

	        stage3D.removeEventListener( ErrorEvent.ERROR, onErrorFunction);

	        stage3D.removeEventListener(Event.CONTEXT3D_CREATE, onContext3DCreateFunction);

	        stage.removeEventListener(Event.RESIZE, kitInstance.performOnScreenSizeChangedFlash);
	    });

		stage3D.requestContext3D(flash.display3D.Context3DRenderMode.AUTO);

		#end
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

		#if flash
	    flash.Lib.current.stage.removeEventListener(Event.ENTER_FRAME, performPreInitializeOnRenderFlash);
		flash.Lib.current.stage.addEventListener(Event.ENTER_FRAME, performOnRenderFlash);
		#else
	    GLContext.onRenderOnMainContext.remove(kitInstance.performPreInitializeOnRender);
	    GLContext.onRenderOnMainContext.add(kitInstance.performOnRender);
		#end

		callbackAfterInitializing = null;
	}

	#if flash
	private function performOnScreenSizeChangedFlash(event: Event) performOnScreenSizeChanged();
	#end
	private function performOnScreenSizeChanged(): Void
	{
		try
		{
			#if flash

			var stage:Stage = flash.Lib.current.stage;
			screenWidth = stage.stageWidth;
			screenHeight = stage.stageHeight;

			#else

			screenWidth = GLContext.getMainContext().contextWidth;
			screenHeight = GLContext.getMainContext().contextHeight;

			#end

			onScreenSizeChanged.dispatch();
		}
		catch(e : Dynamic)
		{
			onError.dispatch(e);
		}
	}

	#if flash
	private function performPreInitializeOnRenderFlash(event: Event) performPreInitializeOnRender();
	#end
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

	#if flash
	private function performOnRenderFlash(event: Event) performOnRender();
	#end
	private function performOnRender(): Void
	{
		try
		{
			#if flash
			var stage:Stage = flash.Lib.current.stage;
			var stage3D : Stage3D = stage.stage3Ds[0];
			#end

            // Input Processing in here
            onEnterFrame.dispatch();

            if (loopTheMainLoopOnRender)
            {
	            // Mainloop, runs the timers, delays and async executions
	            mainLoop.loopMainLoop();
            }

            // Rendering
			if (clearAndPresentDefaultBuffer)
			{
				#if flash
				stage3D.context3D.clear(1, 1, 1, 1.0, 1, 0x00, Context3DClearMask.ALL);
				#else

			    gl.GL.clear(gl.GLDefines.COLOR_BUFFER_BIT | gl.GLDefines.DEPTH_BUFFER_BIT | gl.GLDefines.STENCIL_BUFFER_BIT);

				#end
			}

			onRender.dispatch();

			if (clearAndPresentDefaultBuffer)
			{
				#if flash
				stage3D.context3D.present();
				#end
			}

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
