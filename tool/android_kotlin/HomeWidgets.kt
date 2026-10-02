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
import android.os.SystemClock
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

    fun save(context: Context, prayers: String?, ayahs: String?) {
        val e = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        if (prayers != null) e.putString("prayers", prayers)
        if (ayahs != null) e.putString("ayahs", ayahs)
        e.apply()
    }

    fun prayers(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("prayers", null)

    fun ayahs(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("ayahs", null)

    fun updateAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val prayerIds = mgr.getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
        if (prayerIds.isNotEmpty()) PrayerWidgetProvider.render(context, mgr, prayerIds)
        val ayahIds = mgr.getAppWidgetIds(ComponentName(context, AyahWidgetProvider::class.java))
        if (ayahIds.isNotEmpty()) AyahWidgetProvider.render(context, mgr, ayahIds)
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

    /** Wakes [provider] at [atMillis] so the widget moves to the next prayer / day. */
    fun scheduleUpdate(context: Context, provider: Class<*>, requestCode: Int, atMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, provider).apply { action = AppWidgetManager.ACTION_APPWIDGET_UPDATE }
        val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, provider))
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            val exactOk = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
            if (exactOk) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            }
        } catch (e: Exception) {
            am.set(AlarmManager.RTC_WAKEUP, atMillis, pi)
        }
    }

    private val digits = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')

    fun arabicDigits(s: String): String =
        s.map { if (it in '0'..'9') digits[it - '0'] else it }.joinToString("")

    fun formatTime(millis: Long): String {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        val h = cal.get(Calendar.HOUR).let { if (it == 0) 12 else it }
        val m = cal.get(Calendar.MINUTE)
        val suffix = if (cal.get(Calendar.AM_PM) == Calendar.AM) "ص" else "م"
        return arabicDigits(String.format(Locale.US, "%d:%02d", h, m)) + " " + suffix
    }

    fun dayKey(millis: Long): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(millis))
}

/** Horizontal prayer-times widget with a live countdown to the next prayer. */
class PrayerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) = render(context, mgr, ids)

    companion object {
        private val nameIds = intArrayOf(R.id.p0_name, R.id.p1_name, R.id.p2_name, R.id.p3_name, R.id.p4_name)
        private val timeIds = intArrayOf(R.id.p0_time, R.id.p1_time, R.id.p2_time, R.id.p3_time, R.id.p4_time)
        private val cellIds = intArrayOf(R.id.p0, R.id.p1, R.id.p2, R.id.p3, R.id.p4)

        fun render(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            val views = RemoteViews(context.packageName, R.layout.widget_prayer)
            views.setOnClickPendingIntent(R.id.widget_root, WidgetStore.openAppIntent(context))
            val now = System.currentTimeMillis()

            // {"city": "...", "days": [{"d": "yyyy-MM-dd", "n": [5 names], "t": [5 millis]}]}
            val raw = WidgetStore.prayers(context)
            var nextAt = -1L
            try {
                val root = JSONObject(raw ?: "{}")
                val days: JSONArray = root.optJSONArray("days") ?: JSONArray()
                var dayIndex = -1
                var nextIndex = -1
                loop@ for (i in 0 until days.length()) {
                    val t = days.getJSONObject(i).getJSONArray("t")
                    for (j in 0 until t.length()) {
                        if (t.getLong(j) > now) {
                            dayIndex = i; nextIndex = j; nextAt = t.getLong(j)
                            break@loop
                        }
                    }
                }
                if (dayIndex < 0) throw IllegalStateException("no data")
                val day = days.getJSONObject(dayIndex)
                val names = day.getJSONArray("n")
                val times = day.getJSONArray("t")
                for (j in 0 until 5) {
                    views.setTextViewText(nameIds[j], names.optString(j))
                    views.setTextViewText(timeIds[j], WidgetStore.formatTime(times.getLong(j)))
                    val next = j == nextIndex
                    views.setInt(cellIds[j], "setBackgroundResource", if (next) R.drawable.widget_highlight else 0)
                    views.setTextColor(nameIds[j], if (next) Color.parseColor("#F3DDA6") else Color.parseColor("#B8C2C8"))
                    views.setTextColor(timeIds[j], if (next) Color.WHITE else Color.parseColor("#E6ECEF"))
                }
                views.setTextViewText(R.id.next_label, "المتبقي على صلاة " + names.optString(nextIndex))
                views.setChronometer(R.id.countdown, SystemClock.elapsedRealtime() + (nextAt - now), null, true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) views.setChronometerCountDown(R.id.countdown, true)
                views.setViewVisibility(R.id.countdown, View.VISIBLE)
                views.setTextViewText(R.id.city, root.optString("city", "الهدى"))
            } catch (e: Exception) {
                views.setTextViewText(R.id.next_label, "افتح تطبيق الهدى لتحديث المواقيت")
                views.setViewVisibility(R.id.countdown, View.GONE)
            }
            mgr.updateAppWidget(ids, views)
            if (nextAt > 0) {
                WidgetStore.scheduleUpdate(context, PrayerWidgetProvider::class.java, 4101, nextAt + 1000)
            }
        }
    }
}

/** "آية اليوم" widget: a new verse every day, chosen by the app in advance. */
class AyahWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) = render(context, mgr, ids)

    companion object {
        fun render(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            val views = RemoteViews(context.packageName, R.layout.widget_ayah)
            views.setOnClickPendingIntent(R.id.widget_root, WidgetStore.openAppIntent(context))
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
            mgr.updateAppWidget(ids, views)
            // Refresh shortly after midnight.
            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 1); set(Calendar.SECOND, 0)
            }
            WidgetStore.scheduleUpdate(context, AyahWidgetProvider::class.java, 4102, cal.timeInMillis)
        }
    }
}
