package com.alhuda.islamic.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Data written by the Flutter app (see lib/core/services/home_widgets.dart). */
object WidgetStore {
    private const val PREFS = "alhuda_widgets"
    const val ACTION_TICK = "com.alhuda.islamic.app.WIDGET_TICK"

    // Text colours, from the colour chosen in the app (white by default):
    // main text, dimmer secondary text, and the faintest labels.
    var WHITE = Color.WHITE
    var DIM = Color.parseColor("#FFB8B8B8")
    var MUTED = Color.parseColor("#FFA3A3A3")

    private fun withAlpha(c: Int, a: Int) = (c and 0x00FFFFFF) or (a shl 24)

    private fun style(context: Context): JSONObject = try {
        JSONObject(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("style", null) ?: "{}")
    } catch (e: Exception) {
        JSONObject()
    }

    fun loadColors(context: Context) {
        val c = style(context).optLong("text", 0xFFFFFFFFL).toInt() or (0xFF shl 24)
        WHITE = c
        DIM = withAlpha(c, 0xC4)
        MUTED = withAlpha(c, 0xA8)
    }

    /** Applies the chosen text colour to [ids] (main), [dim] and [muted]. */
    fun paint(v: RemoteViews, main: IntArray = intArrayOf(), dim: IntArray = intArrayOf(), muted: IntArray = intArrayOf(), icons: IntArray = intArrayOf()) {
        for (id in main) v.setTextColor(id, WHITE)
        for (id in dim) v.setTextColor(id, DIM)
        for (id in muted) v.setTextColor(id, MUTED)
        for (id in icons) v.setInt(id, "setColorFilter", WHITE)
    }

    fun save(context: Context, prayers: String?, ayahs: String?, style: String? = null) {
        val e = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        if (prayers != null) e.putString("prayers", prayers)
        if (ayahs != null) e.putString("ayahs", ayahs)
        if (style != null) e.putString("style", style)
        e.apply()
    }

    fun prayers(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("prayers", null)

    fun ayahs(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("ayahs", null)

    /** Background opacity chosen in the app: 0 = transparent, 1 = solid. */
    fun opacity(context: Context): Float = style(context).optDouble("opacity", 1.0).toFloat().coerceIn(0f, 1f)

    fun applyStyle(context: Context, views: RemoteViews) {
        loadColors(context)
        views.setInt(R.id.widget_bg, "setImageAlpha", (opacity(context) * 255).toInt())
        views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))
    }

    val prayerProviders: List<Class<*>> = listOf(
        PrayerWidgetProvider::class.java,
        PrayerNextWidgetProvider::class.java,
        PrayerMinimalWidgetProvider::class.java,
        PrayerListWidgetProvider::class.java,
        PrayerTileWidgetProvider::class.java,
    )

    fun ids(context: Context, provider: Class<*>): IntArray =
        AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, provider))

    fun updatePrayerWidgets(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val now = System.currentTimeMillis()
        val snap = PrayerData.snapshot(context, now)
        var any = false
        for (p in prayerProviders) {
            val ids = ids(context, p)
            if (ids.isEmpty()) continue
            any = true
            mgr.updateAppWidget(ids, PrayerViews.build(context, p, snap, now))
        }
        if (!any) return
        // Wake exactly at the next prayer, and refresh the countdown every
        // minute while the screen is on (non-wakeup alarm: no battery cost).
        if (snap != null) scheduleWake(context, snap.next.at + 1000)
        scheduleTick(context, now)
    }

    fun updateAll(context: Context) {
        updatePrayerWidgets(context)
        val mgr = AppWidgetManager.getInstance(context)
        val ayahIds = ids(context, AyahWidgetProvider::class.java)
        if (ayahIds.isNotEmpty()) AyahWidgetProvider.render(context, mgr, ayahIds)
        val athkarIds = ids(context, AthkarWidgetProvider::class.java)
        if (athkarIds.isNotEmpty()) AthkarWidgetProvider.render(context, mgr, athkarIds)
    }

    fun openAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun canExact(am: AlarmManager) =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()

    /** Wakes [provider] at [atMillis] so the widget moves to the next prayer / day. */
    fun scheduleUpdate(context: Context, provider: Class<*>, requestCode: Int, atMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, provider).apply { action = AppWidgetManager.ACTION_APPWIDGET_UPDATE }
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids(context, provider))
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            if (canExact(am)) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            }
        } catch (e: Exception) {
            am.set(AlarmManager.RTC_WAKEUP, atMillis, pi)
        }
    }

    /** Wakes the prayer widgets at a prayer time (even in doze). */
    private fun scheduleWake(context: Context, atMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, PrayerWidgetProvider::class.java).setAction(ACTION_TICK)
        val pi = PendingIntent.getBroadcast(
            context, 4101, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            if (canExact(am)) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
        } catch (e: Exception) {
            am.set(AlarmManager.RTC_WAKEUP, atMillis, pi)
        }
    }

    /** Next minute boundary, delivered only while the device is awake. */
    private fun scheduleTick(context: Context, now: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, PrayerWidgetProvider::class.java).setAction(ACTION_TICK)
        val pi = PendingIntent.getBroadcast(
            context, 4110, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val at = (now / 60_000L + 1) * 60_000L + 500
        try {
            if (canExact(am)) am.setExact(AlarmManager.RTC, at, pi) else am.set(AlarmManager.RTC, at, pi)
        } catch (e: Exception) {
            am.set(AlarmManager.RTC, at, pi)
        }
    }

    private val digits = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')

    fun arabicDigits(s: String): String =
        s.map { if (it in '0'..'9') digits[it - '0'] else it }.joinToString("")

    /** 12-hour clock without AM/PM, Arabic digits: ١٢:٣٤ */
    fun clock(millis: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        val h = cal.get(Calendar.HOUR).let { if (it == 0) 12 else it }
        return arabicDigits(String.format(Locale.US, "%d:%02d", h, cal.get(Calendar.MINUTE)))
    }

    fun formatTime(millis: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        val suffix = if (cal.get(Calendar.AM_PM) == Calendar.AM) "ص" else "م"
        return clock(millis) + " " + suffix
    }

    /** "بعد ٣ س ٤٣ د" / "بعد ٢٥ دقيقة" / "حان الآن". */
    fun countdown(at: Long, now: Long): String {
        val mins = ((at - now + 59_999L) / 60_000L).toInt()
        if (mins <= 0) return "حان الآن"
        val h = mins / 60
        val m = mins % 60
        val text = when {
            h == 0 -> "بعد " + count(m, "دقيقة", "دقيقتين", "دقائق")
            m == 0 -> "بعد " + count(h, "ساعة", "ساعتين", "ساعات")
            else -> "بعد $h س $m د"
        }
        return arabicDigits(text)
    }

    /** Arabic counting: ١ دقيقة، دقيقتين، ٣–١٠ دقائق، ١١ فأكثر دقيقة. */
    private fun count(n: Int, one: String, two: String, few: String): String = when {
        n == 1 -> one
        n == 2 -> two
        n % 100 in 3..10 -> "$n $few"
        else -> "$n $one"
    }

    fun dayKey(millis: Long): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(millis))
}

/** One prayer (or sunrise) at a moment. */
data class PrayerEvent(val kind: Int, val name: String, val at: Long) {
    companion object {
        const val FAJR = 0
        const val SUNRISE = 1
        const val DHUHR = 2
        const val ASR = 3
        const val MAGHRIB = 4
        const val ISHA = 5
    }
}

object PrayerData {
    /** The day of the next event, its events (sunrise included when known), and neighbours. */
    class Snapshot(
        val day: List<PrayerEvent>,
        val next: PrayerEvent,
        val prev: PrayerEvent?,
        val city: String,
    ) {
        val prayers get() = day.filter { it.kind != PrayerEvent.SUNRISE }
    }

    private val kinds = intArrayOf(PrayerEvent.FAJR, PrayerEvent.DHUHR, PrayerEvent.ASR, PrayerEvent.MAGHRIB, PrayerEvent.ISHA)

    fun snapshot(context: Context, now: Long): Snapshot? = try {
        // {"city": "...", "days": [{"d": "yyyy-MM-dd", "n": [5 names], "t": [5 millis], "s": sunrise}]}
        val root = JSONObject(WidgetStore.prayers(context) ?: "{}")
        val days = root.optJSONArray("days") ?: JSONArray()
        val all = mutableListOf<List<PrayerEvent>>()
        for (i in 0 until days.length()) {
            val d = days.getJSONObject(i)
            val n = d.getJSONArray("n")
            val t = d.getJSONArray("t")
            val list = mutableListOf<PrayerEvent>()
            for (j in 0 until minOf(5, t.length())) list.add(PrayerEvent(kinds[j], n.optString(j), t.getLong(j)))
            val s = d.optLong("s", 0L)
            if (s > 0) list.add(1, PrayerEvent(PrayerEvent.SUNRISE, "الشروق", s))
            all.add(list)
        }
        var result: Snapshot? = null
        loop@ for (i in all.indices) {
            val day = all[i]
            for (j in day.indices) {
                if (day[j].at > now) {
                    val prev = when {
                        j > 0 -> day[j - 1]
                        i > 0 -> all[i - 1].last()
                        else -> day.last().let { PrayerEvent(it.kind, it.name, it.at - 86_400_000L) }
                    }
                    result = Snapshot(day, day[j], prev, root.optString("city", "الهدى"))
                    break@loop
                }
            }
        }
        result
    } catch (e: Exception) {
        null
    }

    /** The prayer name written with its vowels, the way calligraphy shows it. */
    fun voweled(name: String): String = when (name) {
        "الفجر" -> "الفَجْر"
        "الشروق" -> "الشُّرُوق"
        "الظهر" -> "الظُّهْر"
        "الجمعة" -> "الجُمُعَة"
        "العصر" -> "العَصْر"
        "المغرب" -> "المَغْرِب"
        "العشاء" -> "العِشَاء"
        else -> name
    }

    /** The calligraphic name (vowels kept in the same run so they sit right). */
    fun calligraphy(name: String): CharSequence = voweled(name)

    fun icon(kind: Int): Int = when (kind) {
        PrayerEvent.FAJR -> R.drawable.widget_ic_fajr
        PrayerEvent.SUNRISE -> R.drawable.widget_ic_sunrise
        PrayerEvent.DHUHR -> R.drawable.widget_ic_dhuhr
        PrayerEvent.ASR -> R.drawable.widget_ic_asr
        PrayerEvent.MAGHRIB -> R.drawable.widget_ic_maghrib
        else -> R.drawable.widget_ic_isha
    }
}

/** Builds the views of every prayer widget design from one snapshot. */
object PrayerViews {
    private const val NO_DATA = "افتح تطبيق الهدى لتحديث المواقيت"

    fun build(context: Context, provider: Class<*>, snap: PrayerData.Snapshot?, now: Long): RemoteViews = when (provider) {
        PrayerNextWidgetProvider::class.java -> next(context, snap, now)
        PrayerMinimalWidgetProvider::class.java -> minimal(context, snap, now)
        PrayerListWidgetProvider::class.java -> list(context, snap, now)
        PrayerTileWidgetProvider::class.java -> tile(context, snap, now)
        else -> timeline(context, snap, now)
    }

    private fun next(context: Context, snap: PrayerData.Snapshot?, now: Long): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.widget_prayer_next)
        WidgetStore.applyStyle(context, v)
        if (snap == null) {
            v.setTextViewText(R.id.next_name, "الهدى")
            v.setTextViewText(R.id.next_time, "")
            v.setTextViewText(R.id.next_in, NO_DATA)
            return v
        }
        v.setTextViewText(R.id.next_name, PrayerData.calligraphy(snap.next.name))
        v.setTextViewText(R.id.next_time, WidgetStore.clock(snap.next.at))
        v.setTextViewText(R.id.next_in, WidgetStore.countdown(snap.next.at, now))
        WidgetStore.paint(v, main = intArrayOf(R.id.next_name, R.id.next_time), muted = intArrayOf(R.id.next_in))
        return v
    }

    private fun minimal(context: Context, snap: PrayerData.Snapshot?, now: Long): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.widget_prayer_minimal)
        WidgetStore.applyStyle(context, v)
        if (snap == null) {
            v.setTextViewText(R.id.prev_name, NO_DATA)
            v.setTextViewText(R.id.prev_time, "")
            v.setTextViewText(R.id.next_name, "")
            v.setTextViewText(R.id.next_in, "")
            v.setTextViewText(R.id.next_time, "")
            return v
        }
        val prev = snap.prev
        v.setTextViewText(R.id.prev_name, prev?.name ?: "")
        v.setTextViewText(R.id.prev_time, if (prev != null) WidgetStore.clock(prev.at) else "")
        v.setInt(R.id.prev_dot, "setImageAlpha", 150)
        v.setTextViewText(R.id.next_name, snap.next.name)
        v.setTextViewText(R.id.next_in, WidgetStore.countdown(snap.next.at, now))
        v.setTextViewText(R.id.next_time, WidgetStore.clock(snap.next.at))
        WidgetStore.paint(
            v,
            main = intArrayOf(R.id.next_name, R.id.next_time),
            dim = intArrayOf(R.id.prev_name, R.id.prev_time, R.id.next_in),
            icons = intArrayOf(R.id.prev_dot, R.id.next_dot),
        )
        return v
    }

    private val colIds = intArrayOf(R.id.p0, R.id.p1, R.id.p2, R.id.p3, R.id.p4)
    private val dotIds = intArrayOf(R.id.p0_dot, R.id.p1_dot, R.id.p2_dot, R.id.p3_dot, R.id.p4_dot)
    private val nameIds = intArrayOf(R.id.p0_name, R.id.p1_name, R.id.p2_name, R.id.p3_name, R.id.p4_name)
    private val timeIds = intArrayOf(R.id.p0_time, R.id.p1_time, R.id.p2_time, R.id.p3_time, R.id.p4_time)

    private fun timeline(context: Context, snap: PrayerData.Snapshot?, now: Long): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.widget_prayer)
        WidgetStore.applyStyle(context, v)
        if (snap == null) {
            v.setTextViewText(R.id.p2_name, NO_DATA)
            v.setProgressBar(R.id.day_progress, 1000, 0, false)
            return v
        }
        val prayers = snap.prayers
        // The highlighted prayer is the next one (sunrise counts as Dhuhr's turn).
        val nextIdx = prayers.indexOfFirst { it.at > now }.let { if (it < 0) prayers.size - 1 else it }
        for (j in 0 until 5) {
            val p = prayers.getOrNull(j)
            val on = j == nextIdx
            v.setTextViewText(nameIds[j], p?.name ?: "")
            v.setTextViewText(timeIds[j], if (p != null) WidgetStore.clock(p.at) else "")
            v.setTextColor(nameIds[j], if (on) WidgetStore.WHITE else WidgetStore.MUTED)
            v.setTextColor(timeIds[j], if (on) WidgetStore.WHITE else WidgetStore.DIM)
            v.setInt(dotIds[j], "setImageAlpha", if (on) 255 else 110)
            v.setInt(dotIds[j], "setColorFilter", WidgetStore.WHITE)
        }
        if (Build.VERSION.SDK_INT >= 31) {
            v.setColorStateList(R.id.day_progress, "setProgressTintList", android.content.res.ColorStateList.valueOf(WidgetStore.WHITE))
            v.setColorStateList(
                R.id.day_progress, "setProgressBackgroundTintList",
                android.content.res.ColorStateList.valueOf((WidgetStore.WHITE and 0x00FFFFFF) or (0x59 shl 24)),
            )
        }
        // Progress between column centres: 0 at Fajr, 1000 at Isha.
        var progress = 0.0
        for (j in 0 until prayers.size - 1) {
            val a = prayers[j].at
            val b = prayers[j + 1].at
            if (now >= b) progress = (j + 1).toDouble()
            else if (now > a) progress = j + (now - a).toDouble() / (b - a)
        }
        v.setProgressBar(R.id.day_progress, 1000, (progress / (prayers.size - 1) * 1000).toInt().coerceIn(0, 1000), false)
        return v
    }

    private val rowIds = intArrayOf(R.id.r0, R.id.r1, R.id.r2, R.id.r3, R.id.r4, R.id.r5)
    private val rowIcons = intArrayOf(R.id.r0_icon, R.id.r1_icon, R.id.r2_icon, R.id.r3_icon, R.id.r4_icon, R.id.r5_icon)
    private val rowNames = intArrayOf(R.id.r0_name, R.id.r1_name, R.id.r2_name, R.id.r3_name, R.id.r4_name, R.id.r5_name)
    private val rowTimes = intArrayOf(R.id.r0_time, R.id.r1_time, R.id.r2_time, R.id.r3_time, R.id.r4_time, R.id.r5_time)

    private fun list(context: Context, snap: PrayerData.Snapshot?, now: Long): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.widget_prayer_list)
        WidgetStore.applyStyle(context, v)
        if (snap == null) {
            v.setTextViewText(R.id.top_name, "الهدى")
            v.setTextViewText(R.id.top_in, NO_DATA)
            v.setTextViewText(R.id.top_time, "")
            return v
        }
        v.setTextViewText(R.id.top_name, snap.next.name)
        v.setTextViewText(R.id.top_in, WidgetStore.countdown(snap.next.at, now))
        v.setTextViewText(R.id.top_time, WidgetStore.clock(snap.next.at))
        WidgetStore.paint(v, main = intArrayOf(R.id.top_in, R.id.top_time), dim = intArrayOf(R.id.top_name))
        for (j in 0 until 6) {
            val e = snap.day.getOrNull(j)
            if (e == null) {
                v.setViewVisibility(rowIds[j], View.GONE)
                continue
            }
            v.setViewVisibility(rowIds[j], View.VISIBLE)
            val on = e == snap.next
            v.setImageViewResource(rowIcons[j], PrayerData.icon(e.kind))
            v.setInt(rowIcons[j], "setImageAlpha", if (on) 255 else 170)
            v.setInt(rowIcons[j], "setColorFilter", WidgetStore.WHITE)
            v.setTextViewText(rowNames[j], e.name)
            v.setTextViewText(rowTimes[j], WidgetStore.clock(e.at))
            v.setTextColor(rowNames[j], if (on) WidgetStore.WHITE else WidgetStore.DIM)
            v.setTextColor(rowTimes[j], if (on) WidgetStore.WHITE else WidgetStore.DIM)
            v.setInt(rowIds[j], "setBackgroundResource", if (on) R.drawable.widget_row else 0)
        }
        return v
    }

    private fun tile(context: Context, snap: PrayerData.Snapshot?, now: Long): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.widget_prayer_tile)
        WidgetStore.applyStyle(context, v)
        if (snap == null) {
            v.setTextViewText(R.id.tile_name, "الهدى")
            v.setTextViewText(R.id.tile_time, "--:--")
            v.setTextViewText(R.id.tile_in, "افتح التطبيق")
            return v
        }
        v.setImageViewResource(R.id.tile_icon, PrayerData.icon(snap.next.kind))
        v.setTextViewText(R.id.tile_name, snap.next.name)
        v.setTextViewText(R.id.tile_time, WidgetStore.clock(snap.next.at))
        v.setTextViewText(R.id.tile_in, WidgetStore.countdown(snap.next.at, now))
        WidgetStore.paint(
            v,
            main = intArrayOf(R.id.tile_time),
            dim = intArrayOf(R.id.tile_name),
            muted = intArrayOf(R.id.tile_in),
            icons = intArrayOf(R.id.tile_icon),
        )
        return v
    }
}

/** Shared behaviour of the prayer widgets: every update refreshes all designs. */
abstract class PrayerWidgetBase : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) =
        WidgetStore.updatePrayerWidgets(context)

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == WidgetStore.ACTION_TICK) {
            WidgetStore.updatePrayerWidgets(context)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, mgr: AppWidgetManager, id: Int, options: android.os.Bundle
    ) = WidgetStore.updatePrayerWidgets(context)
}

/** Five prayers with the day's progress bar. */
class PrayerWidgetProvider : PrayerWidgetBase()

/** Next prayer: calligraphic name, time and countdown. */
class PrayerNextWidgetProvider : PrayerWidgetBase()

/** Current and next prayer on two lines. */
class PrayerMinimalWidgetProvider : PrayerWidgetBase()

/** The whole day, next prayer on top. */
class PrayerListWidgetProvider : PrayerWidgetBase()

/** Small square: next prayer. */
class PrayerTileWidgetProvider : PrayerWidgetBase()

/** "آية اليوم" widget: a new verse every day, chosen by the app in advance. */
class AyahWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) = render(context, mgr, ids)

    companion object {
        fun build(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_ayah)
            WidgetStore.applyStyle(context, views)
            val today = WidgetStore.dayKey(System.currentTimeMillis())
            try {
                // [{"d": "yyyy-MM-dd", "t": "...", "r": "سورة ... • ..."}]
                val list = JSONArray(WidgetStore.ayahs(context) ?: "[]")
                var item: JSONObject? = null
                for (i in 0 until list.length()) {
                    val o = list.getJSONObject(i)
                    if (o.optString("d") == today) { item = o; break }
                }
                if (item == null && list.length() > 0) item = list.getJSONObject(list.length() - 1)
                if (item == null) throw IllegalStateException("no data")
                views.setTextViewText(R.id.ayah_text, "﴿" + item.optString("t") + "﴾")
                views.setTextViewText(R.id.ayah_ref, item.optString("r"))
            } catch (e: Exception) {
                views.setTextViewText(R.id.ayah_text, "افتح تطبيق الهدى لعرض آية اليوم")
                views.setTextViewText(R.id.ayah_ref, "")
            }
            WidgetStore.paint(views, main = intArrayOf(R.id.ayah_text), muted = intArrayOf(R.id.ayah_title, R.id.ayah_ref))
            return views
        }

        fun render(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            mgr.updateAppWidget(ids, build(context))
            // Refresh shortly after midnight.
            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 1); set(Calendar.SECOND, 0)
            }
            WidgetStore.scheduleUpdate(context, AyahWidgetProvider::class.java, 4102, cal.timeInMillis)
        }
    }
}


/** Athkar widget: the thikr that fits the time of day, with a tap counter. */
class AthkarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) = render(context, mgr, ids)

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_TAP -> step(context, advanceOnly = false)
            ACTION_NEXT -> step(context, advanceOnly = true)
            else -> { super.onReceive(context, intent); return }
        }
        val mgr = AppWidgetManager.getInstance(context)
        render(context, mgr, mgr.getAppWidgetIds(ComponentName(context, AthkarWidgetProvider::class.java)))
    }

    companion object {
        private const val PREFS = "alhuda_athkar_widget"
        private const val ACTION_TAP = "com.alhuda.islamic.app.ATHKAR_TAP"
        private const val ACTION_NEXT = "com.alhuda.islamic.app.ATHKAR_NEXT"

        private data class T(val text: String, val count: Int)

        private val morningEvening = listOf(
            T("بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ", 3),
            T("رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا", 3),
            T("حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ", 7),
            T("لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", 10),
            T("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", 100),
            T("أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ", 100),
        )
        private val sleep = listOf(
            T("بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا", 1),
            T("سُبْحَانَ اللَّهِ", 33),
            T("الْحَمْدُ لِلَّهِ", 33),
            T("اللَّهُ أَكْبَرُ", 34),
        )
        private val general = listOf(
            T("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ", 33),
            T("لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ", 33),
            T("اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ", 10),
            T("لَا إِلَهَ إِلَّا اللَّهُ", 100),
        )

        /** (title, list, set key) for the current hour. */
        private fun current(): Triple<String, List<T>, String> {
            val h = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
            val day = WidgetStore.dayKey(System.currentTimeMillis())
            return when {
                h in 4..11 -> Triple("أذكار الصباح", morningEvening, "m-$day")
                h in 15..19 -> Triple("أذكار المساء", morningEvening, "e-$day")
                h >= 21 || h < 4 -> Triple("أذكار النوم", sleep, "s-$day")
                else -> Triple("ذكر الله", general, "g-$day")
            }
        }

        private fun step(context: Context, advanceOnly: Boolean) {
            val (_, list, key) = current()
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            var index = if (prefs.getString("key", "") == key) prefs.getInt("index", 0) else 0
            var count = if (prefs.getString("key", "") == key) prefs.getInt("count", 0) else 0
            if (index >= list.size) index = 0
            if (advanceOnly) {
                index = (index + 1) % list.size; count = 0
            } else {
                count++
                if (count >= list[index].count) {
                    index = (index + 1) % list.size; count = 0
                }
            }
            prefs.edit().putString("key", key).putInt("index", index).putInt("count", count).apply()
        }

        private fun broadcast(context: Context, action: String, code: Int): PendingIntent {
            val i = Intent(context, AthkarWidgetProvider::class.java).setAction(action)
            return PendingIntent.getBroadcast(context, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun render(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            mgr.updateAppWidget(ids, build(context))
            // Re-render on the next hour so the category follows the time of day.
            val cal = Calendar.getInstance().apply {
                add(Calendar.HOUR_OF_DAY, 1); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 5)
            }
            WidgetStore.scheduleUpdate(context, AthkarWidgetProvider::class.java, 4103, cal.timeInMillis)
        }

        fun build(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_athkar)
            val (title, list, key) = current()
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val same = prefs.getString("key", "") == key
            val index = if (same) prefs.getInt("index", 0).coerceIn(0, list.size - 1) else 0
            val count = if (same) prefs.getInt("count", 0) else 0
            val t = list[index]
            WidgetStore.applyStyle(context, views)
            views.setTextViewText(R.id.athkar_title, title)
            views.setTextViewText(R.id.athkar_step, WidgetStore.arabicDigits("${index + 1}/${list.size}"))
            views.setTextViewText(R.id.athkar_text, t.text)
            views.setTextViewText(
                R.id.athkar_count,
                WidgetStore.arabicDigits("$count / ${t.count}") + "  •  اضغط"
            )
            views.setOnClickPendingIntent(R.id.athkar_count, broadcast(context, ACTION_TAP, 4201))
            views.setOnClickPendingIntent(R.id.athkar_next, broadcast(context, ACTION_NEXT, 4202))
            views.setOnClickPendingIntent(R.id.athkar_text, WidgetStore.openAppIntent(context))
            WidgetStore.paint(
                views,
                main = intArrayOf(R.id.athkar_title, R.id.athkar_text, R.id.athkar_next),
                muted = intArrayOf(R.id.athkar_step),
            )
            return views
        }
    }
}
