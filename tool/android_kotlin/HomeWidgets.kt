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
        val athkarIds = mgr.getAppWidgetIds(ComponentName(context, AthkarWidgetProvider::class.java))
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
                // Living sky: background follows the part of the day.
                val today = days.getJSONObject(0).getJSONArray("t")
                val fajr = today.getLong(0); val dhuhr = today.getLong(1)
                val maghrib = today.getLong(3); val isha = today.getLong(4)
                val sky = when {
                    now < fajr || now >= isha -> R.drawable.widget_sky_night
                    now < fajr + 80 * 60_000L -> R.drawable.widget_sky_dawn
                    now < dhuhr -> R.drawable.widget_sky_morning
                    now < maghrib - 40 * 60_000L -> R.drawable.widget_sky_afternoon
                    else -> R.drawable.widget_sky_sunset
                }
                views.setInt(R.id.widget_root, "setBackgroundResource", sky)
                val boundaries = longArrayOf(fajr + 80 * 60_000L, maghrib - 40 * 60_000L)
                for (b in boundaries) if (b > now && (nextAt <= 0 || b < nextAt)) nextAt = b
                views.setTextViewText(R.id.next_label, "المتبقي على صلاة " + names.optString(nextIndex))
                val prayerAt = times.getLong(nextIndex)
                views.setChronometer(R.id.countdown, SystemClock.elapsedRealtime() + (prayerAt - now), null, true)
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
            val views = RemoteViews(context.packageName, R.layout.widget_athkar)
            val (title, list, key) = current()
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val same = prefs.getString("key", "") == key
            val index = if (same) prefs.getInt("index", 0).coerceIn(0, list.size - 1) else 0
            val count = if (same) prefs.getInt("count", 0) else 0
            val t = list[index]
            val bg = when (key.first()) {
                'm' -> R.drawable.widget_sky_morning
                'e' -> R.drawable.widget_sky_sunset
                's' -> R.drawable.widget_sky_night
                else -> R.drawable.widget_bg
            }
            views.setInt(R.id.widget_root, "setBackgroundResource", bg)
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
            mgr.updateAppWidget(ids, views)
            // Re-render on the next hour so the category follows the time of day.
            val cal = Calendar.getInstance().apply {
                add(Calendar.HOUR_OF_DAY, 1); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 5)
            }
            WidgetStore.scheduleUpdate(context, AthkarWidgetProvider::class.java, 4103, cal.timeInMillis)
        }
    }
}
