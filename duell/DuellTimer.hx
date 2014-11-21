package duell;

import haxe.Timer;
import msignal.Signal.Signal1;

class DuellTimer
{
    public var onFire(default, null): Signal1<Float>;
    public var paused(default, null): Bool = false;

    public var timeScale: Float = 1.0;

    public var currentTime(default, null) : Float = 0.0;
    public var relFrameDelta(default, null) : Float = 0.0;

    private var relFrameStartTime(default, null) : Float = 0.0;

    public var tickDivider(default, null): Int;

    private var currentTick: Int = 0;

    public function new(?tickDivider = 1): Void
    {
        set_tickDivider(tickDivider);
        onFire = new Signal1();
    }

    private function set_tickDivider(value: Int): Int
    {
        if (value < 1)
        {
            value = 1;
        }
        this.tickDivider = value;
        return value;
    }

    /// You need some logic to tick the timer with the real time delta
    private function tick(absoluteDeltaTime: Float): Void
    {
        if (paused)
        {
            return;
        }

        ++currentTick;

        if (currentTick % tickDivider == 0)
        {
            currentTick = 0;

            if (tickDivider == 1)
            {
                relFrameStartTime = DuellKit.instance().frameStartTime;
                relFrameDelta = absoluteDeltaTime * timeScale;
            }
            else
            {
                // Since we are missing frames we measure time over several frames.
                // As more frames we drop as bigger gets the relFrameDelta
                var newCurrentTime = Timer.stamp();
                relFrameDelta = (newCurrentTime - relFrameStartTime) * timeScale;
                relFrameStartTime = newCurrentTime;
            }

            currentTime += relFrameDelta;

            onFire.dispatch(relFrameDelta);
        }
    }

    /// If the Timer is paused you can tick the timer manually
    public function manualTick(?absoluteDeltaTime: Float = 1.0/60.0): Void
    {
        if (!paused)
        {
            return;
        }

        relFrameDelta = absoluteDeltaTime * timeScale;
        currentTime += relFrameDelta;
        onFire.dispatch(relFrameDelta);
    }

    public function stop(): Void
    {
        paused = true;
    }

    public function start(): Void
    {
        paused = false;

        currentTick = 0;
        relFrameDelta = 0.0;
        relFrameStartTime = Timer.stamp();
    }

    public function reset(): Void
    {
        currentTime = 0.0;
    }
}
