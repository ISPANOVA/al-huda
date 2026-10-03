package com.alhuda.islamic.app

import android.app.Activity
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject

/** CI only: renders every home-screen widget so screenshots can be taken. */
class WidgetPreviewActivity : Activity() {
    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val opacity = intent.getFloatExtra("opacity", 1f)
        val page = intent.getIntExtra("page", 0)
        val now = System.currentTimeMillis()
        val h = 3_600_000L
        val m = 60_000L
        val days = JSONArray()
        for (d in 0 until 3) {
            val base = now + d * 24 * h
            days.put(JSONObject().apply {
                put("d", WidgetStore.dayKey(base))
                put("n", JSONArray(listOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")))
                put("t", JSONArray(listOf(base - 6 * h, base + 3 * h + 43 * m, base + 6 * h + 50 * m, base + 9 * h + 40 * m, base + 11 * h)))
                put("s", base - 4 * h - 30 * m)
            })
        }
        val prayers = JSONObject().put("city", "القاهرة").put("days", days).toString()
        val ayahs = JSONArray().put(JSONObject().put("d", WidgetStore.dayKey(now))
            .put("t", "إِنَّ مَعَ ٱلۡعُسۡرِ يُسۡرٗا").put("r", "سورة الشرح • ٦")).toString()
        WidgetStore.save(this, prayers, ayahs, JSONObject().put("opacity", opacity.toDouble()).toString())

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(28), dp(16), dp(28))
        }
        val scroll = ScrollView(this).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(Color.parseColor("#3B2A6B"), Color.parseColor("#B4553D"), Color.parseColor("#1E6B73"))
            )
            addView(column)
        }
        setContentView(scroll)
        val snap = PrayerData.snapshot(this, now)
        val items: List<Triple<String, android.widget.RemoteViews, Pair<Int, Int>>> = if (page == 0) listOf(
            Triple("الصلاة القادمة", PrayerViews.build(this, PrayerNextWidgetProvider::class.java, snap, now), -1 to 120),
            Triple("الحالية والقادمة", PrayerViews.build(this, PrayerMinimalWidgetProvider::class.java, snap, now), -1 to 130),
            Triple("شريط اليوم", PrayerViews.build(this, PrayerWidgetProvider::class.java, snap, now), -1 to 120),
            Triple("مربع صغير", PrayerViews.build(this, PrayerTileWidgetProvider::class.java, snap, now), 170 to 170),
        ) else listOf(
            Triple("مواقيت اليوم", PrayerViews.build(this, PrayerListWidgetProvider::class.java, snap, now), -1 to 380),
            Triple("آية اليوم", AyahWidgetProvider.build(this), -1 to 170),
            Triple("الأذكار", AthkarWidgetProvider.build(this), -1 to 200),
        )
        for ((label, views, size) in items) {
            column.addView(TextView(this).apply {
                text = label
                setTextColor(Color.WHITE)
                textSize = 12f
                setPadding(0, dp(6), 0, dp(6))
            })
            val v = views.apply(this, column)
            column.addView(v, LinearLayout.LayoutParams(
                if (size.first < 0) ViewGroup.LayoutParams.MATCH_PARENT else dp(size.first), dp(size.second)
            ).apply { bottomMargin = dp(12) })
        }
    }
}
