package com.wucai.tomato_clock

import android.app.NotificationChannel
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import java.io.File
import java.time.Instant
import kotlin.math.max
import org.json.JSONArray
import org.json.JSONObject

class TomatoOverlayService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var modeText: TextView? = null
    private var timeText: TextView? = null
    private var stateText: TextView? = null
    private var state = OverlayState()
    private var completing = false

    private val tickRunnable = object : Runnable {
        override fun run() {
            if (!state.isRunning) {
                return
            }
            val remaining = state.remainingFromClock()
            if (remaining <= 0) {
                completeAndStop()
                return
            }
            state = state.copy(remainingSeconds = remaining)
            render()
            updateNotification()
            handler.postDelayed(this, 1000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopOverlay()
                return START_NOT_STICKY
            }

            ACTION_SHOW -> {
                state = OverlayState.fromIntent(intent)
                startForeground(NOTIFICATION_ID, buildNotification())
                showOverlayIfAllowed()
                render()
                restartTicker()
                return START_STICKY
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tickRunnable)
        removeOverlayView()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun showOverlayIfAllowed() {
        if (!Settings.canDrawOverlays(this) || overlayView != null) {
            return
        }
        val view = buildOverlayView()
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            android.graphics.PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(18)
            y = dp(100)
        }
        try {
            windowManager?.addView(view, params)
            overlayView = view
            layoutParams = params
        } catch (_: SecurityException) {
            overlayView = null
            layoutParams = null
        }
    }

    private fun buildOverlayView(): View {
        val background = GradientDrawable().apply {
            cornerRadius = dp(16).toFloat()
            setColor(Color.parseColor("#E61F252B"))
            setStroke(dp(1), Color.parseColor("#33FFFFFF"))
        }
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(10), dp(14), dp(12))
            this.background = background
            elevation = dp(8).toFloat()
        }

        modeText = TextView(this).apply {
            setTextColor(Color.parseColor("#D7DEE5"))
            textSize = 12f
            typeface = Typeface.DEFAULT_BOLD
        }
        timeText = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 28f
            typeface = Typeface.MONOSPACE
            includeFontPadding = false
        }
        stateText = TextView(this).apply {
            setTextColor(Color.parseColor("#B4C0CA"))
            textSize = 11f
        }

        panel.addView(modeText)
        panel.addView(timeText)
        panel.addView(stateText)
        panel.setOnTouchListener(DragListener())
        return panel
    }

    private fun render() {
        modeText?.text = state.modeLabel
        timeText?.text = formatClock(state.remainingSeconds)
        stateText?.text = when (state.phase) {
            "paused" -> "已暂停"
            "running" -> "运行中"
            else -> "待开始"
        }
    }

    private fun restartTicker() {
        handler.removeCallbacks(tickRunnable)
        if (state.isRunning) {
            handler.postDelayed(tickRunnable, 1000L)
        }
        updateNotification()
    }

    private fun completeAndStop() {
        if (completing) {
            return
        }
        completing = true
        handler.removeCallbacks(tickRunnable)
        persistCompletion()
        stopOverlay()
    }

    private fun persistCompletion() {
        val nowMillis = System.currentTimeMillis()
        val file = File(filesDir, "tomato_data.json")
        val data = try {
            if (file.exists()) JSONObject(file.readText()) else JSONObject()
        } catch (_: Exception) {
            JSONObject()
        }
        val settings = data.optJSONObject("settings") ?: JSONObject()
        val focusMinutes = settings.optInt("focusMinutes", 25).coerceAtLeast(1)
        val shortMinutes = settings.optInt("shortBreakMinutes", 5).coerceAtLeast(1)
        val longMinutes = settings.optInt("longBreakMinutes", 15).coerceAtLeast(1)
        val longEvery = settings.optInt("roundsBeforeLongBreak", 4).coerceAtLeast(1)
        val sessions = data.optJSONArray("sessions") ?: JSONArray()
        val nextMode: String
        val nextTotalSeconds: Int

        if (state.mode == "focus") {
            val completedCount = data.optInt("focusCycleCount", 0) + 1
            data.put("focusCycleCount", completedCount)
            sessions.put(
                JSONObject()
                    .put("id", "focus-${state.endsAtMillis.takeIf { it > 0L } ?: nowMillis}")
                    .put("startedAt", Instant.ofEpochMilli(state.startedAtMillis()).toString())
                    .put("endedAt", Instant.ofEpochMilli(nowMillis).toString())
                    .put("plannedSeconds", state.totalSeconds)
                    .put("focusedSeconds", state.totalSeconds)
                    .put("completed", true)
            )
            data.put("sessions", sessions)
            nextMode = if (completedCount % longEvery == 0) "longBreak" else "shortBreak"
            nextTotalSeconds = if (nextMode == "longBreak") longMinutes * 60 else shortMinutes * 60
        } else {
            nextMode = "focus"
            nextTotalSeconds = focusMinutes * 60
        }

        data.put("schemaVersion", 1)
        data.put("updatedAt", Instant.ofEpochMilli(nowMillis).toString())
        data.put(
            "timer",
            JSONObject()
                .put("mode", nextMode)
                .put("phase", "idle")
                .put("totalSeconds", nextTotalSeconds)
                .put("remainingSeconds", nextTotalSeconds)
                .put("startedAt", JSONObject.NULL)
                .put("endsAt", JSONObject.NULL)
                .put("pausedAt", JSONObject.NULL)
        )

        try {
            file.writeText(data.toString(2))
        } catch (_: Exception) {
            // The foreground Flutter app will reconcile from endsAt if this write fails.
        }
    }

    private fun stopOverlay() {
        handler.removeCallbacks(tickRunnable)
        removeOverlayView()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun removeOverlayView() {
        val view = overlayView ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: IllegalArgumentException) {
        }
        overlayView = null
        layoutParams = null
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("番茄钟")
            .setContentText("${state.modeLabel} ${formatClock(state.remainingSeconds)}")
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(Notification.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun openAppIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getActivity(this, 0, intent, flags)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "番茄钟悬浮窗",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "后台倒计时与悬浮窗"
            setShowBadge(false)
        }
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun formatClock(seconds: Int): String {
        val safe = seconds.coerceAtLeast(0)
        val hours = safe / 3600
        val minutes = (safe % 3600) / 60
        val secs = safe % 60
        return if (hours > 0) {
            "%d:%02d:%02d".format(hours, minutes, secs)
        } else {
            "%02d:%02d".format(minutes, secs)
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private inner class DragListener : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var downX = 0f
        private var downY = 0f

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            val params = layoutParams ?: return false
            val manager = windowManager ?: return false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    downX = event.rawX
                    downY = event.rawY
                    return true
                }

                MotionEvent.ACTION_MOVE -> {
                    params.x = startX + (event.rawX - downX).toInt()
                    params.y = startY + (event.rawY - downY).toInt()
                    manager.updateViewLayout(view, params)
                    return true
                }
            }
            return false
        }
    }

    private data class OverlayState(
        val mode: String = "focus",
        val modeLabel: String = "专注",
        val phase: String = "idle",
        val totalSeconds: Int = 1500,
        val remainingSeconds: Int = 1500,
        val endsAtMillis: Long = 0L
    ) {
        val isRunning: Boolean
            get() = phase == "running"

        fun remainingFromClock(): Int {
            if (!isRunning || endsAtMillis <= 0L) {
                return remainingSeconds
            }
            return max(0, ((endsAtMillis - System.currentTimeMillis()) / 1000L).toInt())
        }

        fun startedAtMillis(): Long {
            return if (endsAtMillis > 0L) {
                endsAtMillis - (totalSeconds * 1000L)
            } else {
                System.currentTimeMillis() - (totalSeconds * 1000L)
            }
        }

        companion object {
            fun fromIntent(intent: Intent): OverlayState {
                val phase = intent.getStringExtra(EXTRA_PHASE) ?: "idle"
                val total = intent.getIntExtra(EXTRA_TOTAL_SECONDS, 1500).coerceAtLeast(1)
                val remaining = intent.getIntExtra(EXTRA_REMAINING_SECONDS, total).coerceAtLeast(0)
                val endsAt = intent.getLongExtra(EXTRA_ENDS_AT_MILLIS, 0L)
                return OverlayState(
                    mode = intent.getStringExtra(EXTRA_MODE) ?: "focus",
                    modeLabel = intent.getStringExtra(EXTRA_MODE_LABEL) ?: "专注",
                    phase = phase,
                    totalSeconds = total,
                    remainingSeconds = if (phase == "running" && endsAt > 0L) {
                        max(0, ((endsAt - System.currentTimeMillis()) / 1000L).toInt())
                    } else {
                        remaining
                    },
                    endsAtMillis = endsAt
                )
            }
        }
    }

    companion object {
        private const val ACTION_SHOW = "com.wucai.tomato_clock.SHOW_OVERLAY"
        private const val ACTION_STOP = "com.wucai.tomato_clock.STOP_OVERLAY"
        private const val CHANNEL_ID = "tomato_clock_overlay"
        private const val NOTIFICATION_ID = 2510
        private const val EXTRA_MODE = "mode"
        private const val EXTRA_MODE_LABEL = "modeLabel"
        private const val EXTRA_PHASE = "phase"
        private const val EXTRA_TOTAL_SECONDS = "totalSeconds"
        private const val EXTRA_REMAINING_SECONDS = "remainingSeconds"
        private const val EXTRA_ENDS_AT_MILLIS = "endsAtMillis"

        fun show(context: Context, args: Map<*, *>) {
            val intent = Intent(context, TomatoOverlayService::class.java).apply {
                action = ACTION_SHOW
                putExtra(EXTRA_MODE, args["mode"] as? String ?: "focus")
                putExtra(EXTRA_MODE_LABEL, args["modeLabel"] as? String ?: "专注")
                putExtra(EXTRA_PHASE, args["phase"] as? String ?: "idle")
                putExtra(EXTRA_TOTAL_SECONDS, toInt(args["totalSeconds"], 1500))
                putExtra(EXTRA_REMAINING_SECONDS, toInt(args["remainingSeconds"], 1500))
                putExtra(EXTRA_ENDS_AT_MILLIS, toLong(args["endsAtMillis"], 0L))
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, TomatoOverlayService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        private fun toInt(value: Any?, fallback: Int): Int {
            return when (value) {
                is Int -> value
                is Long -> value.toInt()
                is Double -> value.toInt()
                is Float -> value.toInt()
                is String -> value.toIntOrNull() ?: fallback
                else -> fallback
            }
        }

        private fun toLong(value: Any?, fallback: Long): Long {
            return when (value) {
                is Long -> value
                is Int -> value.toLong()
                is Double -> value.toLong()
                is Float -> value.toLong()
                is String -> value.toLongOrNull() ?: fallback
                else -> fallback
            }
        }
    }
}
