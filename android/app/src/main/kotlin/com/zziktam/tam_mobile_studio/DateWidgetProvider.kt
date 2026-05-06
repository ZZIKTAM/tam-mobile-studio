package com.zziktam.tam_mobile_studio

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.util.Calendar

class DateWidgetProvider : HomeWidgetProvider() {

    private val dayLabels = arrayOf("일", "월", "화", "수", "목", "금", "토")

    private val chipDateIds = intArrayOf(
        R.id.tv_chip_date_0, R.id.tv_chip_date_1, R.id.tv_chip_date_2,
        R.id.tv_chip_date_3, R.id.tv_chip_date_4
    )
    private val chipDayIds = intArrayOf(
        R.id.tv_chip_day_0, R.id.tv_chip_day_1, R.id.tv_chip_day_2,
        R.id.tv_chip_day_3, R.id.tv_chip_day_4
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) { try {
        val ddayStr      = widgetData.getString("widgetDday", "--") ?: "--"
        val nextTitle    = widgetData.getString("widgetNextTitle", "") ?: ""
        val nextDate     = widgetData.getString("widgetNextDate", "") ?: ""
        val nextEmoji    = widgetData.getString("widgetNextEmoji", "📅") ?: "📅"
        val eventsJson   = widgetData.getString("widgetEventsJson", "[]") ?: "[]"

        // Parse upcoming events for mini calendar bar (up to 5)
        data class ChipInfo(val dayLabel: String, val dateNum: String, val isToday: Boolean, val hasEvent: Boolean)
        val chips = mutableListOf<ChipInfo>()
        val now = Calendar.getInstance()
        val todayYear  = now.get(Calendar.YEAR)
        val todayMonth = now.get(Calendar.MONTH) + 1 // 1-indexed
        val todayDay   = now.get(Calendar.DAY_OF_MONTH)

        // Always include today as first chip
        val todayDow = now.get(Calendar.DAY_OF_WEEK) - 1 // 0=Sun
        chips.add(ChipInfo(dayLabels[todayDow], todayDay.toString(), isToday = true, hasEvent = false))

        // Parse event dates for remaining chips
        try {
            val arr = JSONArray(eventsJson)
            var added = 0
            for (i in 0 until arr.length()) {
                if (chips.size >= 5) break
                val obj = arr.getJSONObject(i)
                val dateParts = obj.optString("date", "").split("-")
                if (dateParts.size != 3) continue
                val eYear  = dateParts[0].toIntOrNull() ?: continue
                val eMonth = dateParts[1].toIntOrNull() ?: continue
                val eDay   = dateParts[2].toIntOrNull() ?: continue
                // Skip if same as today
                if (eYear == todayYear && eMonth == todayMonth && eDay == todayDay) continue
                val evCal = Calendar.getInstance()
                evCal.set(eYear, eMonth - 1, eDay)
                val dow = evCal.get(Calendar.DAY_OF_WEEK) - 1
                chips.add(ChipInfo(dayLabels[dow], eDay.toString(), isToday = false, hasEvent = true))
                added++
            }
        } catch (_: Exception) {}

        // Fill remaining chips with consecutive days after last chip date
        // (pad to 5 chips total with empty slots if fewer events)
        while (chips.size < 5) {
            chips.add(ChipInfo("", "", isToday = false, hasEvent = false))
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.home_widget_large)

            // D-Day badge
            views.setTextViewText(R.id.tv_dday, ddayStr)

            // Next event
            views.setTextViewText(R.id.tv_next_emoji, nextEmoji.ifEmpty { "📅" })
            views.setTextViewText(R.id.tv_next_title, nextTitle.ifEmpty { "일정 없음" })
            views.setTextViewText(R.id.tv_next_date, nextDate)

            // Mini calendar bar chips
            for (i in 0 until 5) {
                val chip = chips[i]
                views.setTextViewText(chipDayIds[i], chip.dayLabel)
                views.setTextViewText(chipDateIds[i], chip.dateNum)

                val bgRes = when {
                    chip.isToday  -> R.drawable.widget_chip_today_bg
                    chip.hasEvent -> R.drawable.widget_chip_event_bg
                    else          -> android.R.color.transparent
                }
                views.setInt(chipDateIds[i], "setBackgroundResource", bgRes)

                val textColor = when {
                    chip.isToday  -> Color.WHITE
                    chip.hasEvent -> Color.parseColor("#0A84FF")
                    else          -> Color.parseColor("#0F0F1E")
                }
                views.setTextColor(chipDateIds[i], textColor)
                views.setTextColor(chipDayIds[i], Color.parseColor("#6B6B7A"))
            }

            // Tap widget → open app
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pi = android.app.PendingIntent.getActivity(
                    context, 0, launchIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.tv_dday, pi)
                views.setOnClickPendingIntent(R.id.tv_next_title, pi)
            }

            appWidgetManager.updateAppWidget(id, views)
        }
    } catch (_: Throwable) {} }
}
