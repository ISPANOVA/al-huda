package com.alhuda.islamic.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import org.json.JSONArray
import org.json.JSONObject

/**
 * "Always play" adhan: an exact alarm starts [AdhanService], which plays the
 * adhan on the ALARM audio stream. The alarm stream is not muted by silent or
 * vibrate mode, so the adhan is heard like an alarm clock.
 */
object AdhanAlarm {
    private const val PREFS = "alhuda_adhan"
    private const val KEY = "items"
    const val EXTRA_SOUND = "sound"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"
    const val ACTION_FIRE = "com.alhuda.islamic.app.ADHAN_FIRE"

    /** items: [{id, at (epoch ms), sound, title, body}] — replaces previous schedule. */
    fun schedule(ctx: Context, items: List<Map<String, Any?>>) {
        cancelAll(ctx)
        val arr = JSONArray()
        val now = System.currentTimeMillis()
        for (m in items) {
            val at = (m["at"] as Number).toLong()
            if (at <= now) continue
            val o = JSONObject()
            o.put("id", (m["id"] as Number).toInt())
            o.put("at", at)
            o.put("sound", m["sound"] as String? ?: "")
            o.put("title", m["title"] as String? ?: "")
            o.put("body", m["body"] as String? ?: "")
            arr.put(o)
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
        register(ctx, arr)
    }

    /** One-off alarm that is not stored (settings "test in 10 seconds"). */
    fun scheduleTest(ctx: Context, seconds: Int, sound: String, title: String, body: String) {
        val o = JSONObject()
        o.put("id", 999)
        o.put("at", System.currentTimeMillis() + seconds * 1000L)
        o.put("sound", sound)
        o.put("title", title)
        o.put("body", body)
        register(ctx, JSONArray().put(o))
    }

    /** Re-arms stored alarms (after reboot or app update). */
    fun restore(ctx: Context) {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return
        try {
            register(ctx, JSONArray(raw))
        } catch (_: Exception) {
        }
    }

    private fun register(ctx: Context, arr: JSONArray) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val at = o.getLong("at")
            if (at <= now) continue
            val pi = pending(ctx, o.getInt("id"), o.getString("sound"), o.getString("title"), o.getString("body"))
            val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
            try {
                if (exact) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                } else {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                }
            } catch (_: SecurityException) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            }
        }
    }

    fun cancelAll(ctx: Context) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY, null) ?: return
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                am.cancel(pending(ctx, o.getInt("id"), "", "", ""))
            }
        } catch (_: Exception) {
        }
        prefs.edit().remove(KEY).apply()
    }

    private fun pending(ctx: Context, id: Int, sound: String, title: String, body: String): PendingIntent {
        val intent = Intent(ctx, AdhanReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra(EXTRA_SOUND, sound)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        return PendingIntent.getBroadcast(
            ctx, 7000 + id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun playNow(ctx: Context, sound: String, title: String, body: String) {
        val i = Intent(ctx, AdhanService::class.java).apply {
            putExtra(EXTRA_SOUND, sound)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ctx.startForegroundService(i) else ctx.startService(i)
    }

    fun stop(ctx: Context) {
        ctx.startService(Intent(ctx, AdhanService::class.java).setAction(AdhanService.ACTION_STOP))
    }
}

class AdhanReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            AdhanAlarm.ACTION_FIRE -> AdhanAlarm.playNow(
                context,
                intent.getStringExtra(AdhanAlarm.EXTRA_SOUND) ?: "",
                intent.getStringExtra(AdhanAlarm.EXTRA_TITLE) ?: "حان وقت الصلاة",
                intent.getStringExtra(AdhanAlarm.EXTRA_BODY) ?: ""
            )
            else -> AdhanAlarm.restore(context) // boot / app update
        }
    }
}

class AdhanService : Service() {
    companion object {
        const val ACTION_STOP = "com.alhuda.islamic.app.ADHAN_STOP"
        private const val CHANNEL = "alhuda_adhan_live_v1"
        private const val NOTIF_ID = 4711
    }

    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            finish()
            return START_NOT_STICKY
        }
        val sound = intent?.getStringExtra(AdhanAlarm.EXTRA_SOUND) ?: ""
        val title = intent?.getStringExtra(AdhanAlarm.EXTRA_TITLE) ?: "حان وقت الصلاة"
        val body = intent?.getStringExtra(AdhanAlarm.EXTRA_BODY) ?: ""
        val notification = buildNotification(title, body)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIF_ID, notification)
        }
        play(sound)
        return START_NOT_STICKY
    }

    private fun play(sound: String) {
        releasePlayer()
        val resId = if (sound.isEmpty()) 0 else resources.getIdentifier(sound, "raw", packageName)
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(attrs)
                    .build()
                am.requestAudioFocus(focus!!)
            }
            val uri = if (resId != 0) {
                Uri.parse("android.resource://$packageName/$resId")
            } else {
                android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI
            }
            player = MediaPlayer().apply {
                setAudioAttributes(attrs)
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                setDataSource(applicationContext, uri)
                setOnCompletionListener { finish() }
                setOnErrorListener { _, _, _ -> finish(); true }
                prepare()
                start()
            }
        } catch (_: Exception) {
            finish()
        }
    }

    private fun buildNotification(title: String, body: String): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm.getNotificationChannel(CHANNEL) == null) {
            val ch = NotificationChannel(CHANNEL, "الأذان (يعمل دائمًا)", NotificationManager.IMPORTANCE_HIGH)
            ch.description = "يُشغَّل الأذان حتى لو كان الهاتف صامتًا أو على الاهتزاز"
            ch.setSound(null, null)
            ch.enableVibration(false)
            nm.createNotificationChannel(ch)
        }
        val stopIntent = PendingIntent.getService(
            this, 1, Intent(this, AdhanService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 2, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val icon = resources.getIdentifier("ic_stat_alhuda", "drawable", packageName).takeIf { it != 0 }
            ?: applicationInfo.icon
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_MAX)
        }
        return builder
            .setSmallIcon(icon)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(Notification.CATEGORY_ALARM)
            .setColor(0xFFC9A44C.toInt())
            .setOngoing(true)
            .setContentIntent(open)
            .setDeleteIntent(stopIntent)
            .addAction(Notification.Action.Builder(null, "إيقاف الأذان", stopIntent).build())
            .build()
    }

    private fun releasePlayer() {
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        player?.release()
        player = null
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focus?.let { am.abandonAudioFocusRequest(it) }
        }
        focus = null
    }

    private fun finish() {
        releasePlayer()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        releasePlayer()
        super.onDestroy()
    }
}
