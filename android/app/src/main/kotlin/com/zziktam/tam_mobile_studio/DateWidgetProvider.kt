package com.zziktam.tam_mobile_studio

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.util.Calendar

class DateWidgetProvider : HomeWidgetProvider() {

    // Cell resource IDs in row-major order (6 rows × 7 cols = 42 cells)
    private val cellIds = intArrayOf(
        R.id.tv_d00, R.id.tv_d01, R.id.tv_d02, R.id.tv_d03, R.id.tv_d04, R.id.tv_d05, R.id.tv_d06,
        R.id.tv_d07, R.id.tv_d08, R.id.tv_d09, R.id.tv_d10, R.id.tv_d11, R.id.tv_d12, R.id.tv_d13,
        R.id.tv_d14, R.id.tv_d15, R.id.tv_d16, R.id.tv_d17, R.id.tv_d18, R.id.tv_d19, R.id.tv_d20,
        R.id.tv_d21, R.id.tv_d22, R.id.tv_d23, R.id.tv_d24, R.id.tv_d25, R.id.tv_d26, R.id.tv_d27,
        R.id.tv_d28, R.id.tv_d29, R.id.tv_d30, R.id.tv_d31, R.id.tv_d32, R.id.tv_d33, R.id.tv_d34,
        R.id.tv_d35, R.id.tv_d36, R.id.tv_d37, R.id.tv_d38, R.id.tv_d39, R.id.tv_d40, R.id.tv_d41
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        val monthStr = widgetData.getString("widgetMonth", "") ?: ""
        val preview = widgetData.getString("widgetEventPreview", "일정 없음") ?: "일정 없음"
        val datesJson = widgetData.getString("widgetDatesJson", "[]") ?: "[]"

        // Parse event days
        val eventDays = mutableSetOf<Int>()
        try {
            val arr = JSONArray(datesJson)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val dateParts = obj.getString("date").split("-")
                if (dateParts.size == 3) {
                    dateParts[2].toIntOrNull()?.let { eventDays.add(it) }
                }
            }
        } catch (_: Exception) {}

        // Calendar calculations
        val now = Calendar.getInstance()
        val today = now.get(Calendar.DAY_OF_MONTH)
        val cal = Calendar.getInstance()
        cal.set(Calendar.DAY_OF_MONTH, 1)
        // DAY_OF_WEEK: 1=Sun, 2=Mon ... 7=Sat → offset 0..6
        val firstDayOffset = cal.get(Calendar.DAY_OF_WEEK) - 1
        val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.home_widget_large)

            // Month header
            val displayMonth = monthStr.ifEmpty {
                val months = arrayOf("January","February","March","April","May","June",
                    "July","August","September","October","November","December")
                "${months[now.get(Calendar.MONTH)]} ${now.get(Calendar.YEAR)}"
            }
            views.setTextViewText(R.id.tv_month, displayMonth)
            views.setTextViewText(R.id.tv_event_preview, preview)

            // Fill calendar cells
            var day = 1
            for (idx in 0 until 42) {
                val cellId = cellIds[idx]
                val col = idx % 7
                if (idx < firstDayOffset || day > daysInMonth) {
                    views.setTextViewText(cellId, "")
                } else {
                    views.setTextViewText(cellId, day.toString())
                    val color = when {
                        day == today -> Color.parseColor("#A78BFA")   // today: purple
                        eventDays.contains(day) -> Color.parseColor("#E8A598")  // event: rose
                        col == 0 -> Color.parseColor("#E8A598")       // Sunday: rose
                        col == 6 -> Color.parseColor("#A78BFA")       // Saturday: purple
                        else -> Color.parseColor("#CDD6F4")           // normal
                    }
                    views.setTextColor(cellId, color)
                    day++
                }
            }

            // Tap → open app
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (intent != null) {
                val pi = android.app.PendingIntent.getActivity(
                    context, 0, intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)
            }

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
