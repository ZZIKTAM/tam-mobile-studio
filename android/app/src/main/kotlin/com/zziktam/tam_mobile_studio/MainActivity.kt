package com.zziktam.tam_mobile_studio

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.CalendarContract
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val INSTALLER_CHANNEL = "com.zziktam.tam_mobile_studio/installer"
    private val CALENDAR_CHANNEL = "tam/native_calendar"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // APK installer channel (unchanged)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    installApk(filePath)
                    result.success(true)
                } else {
                    result.error("NO_PATH", "File path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Native calendar bridge — Samsung-safe, full catch(Throwable)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALENDAR_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "listCalendars" -> {
                    try {
                        result.success(listCalendars())
                    } catch (t: Throwable) {
                        result.error("CAL_ERR", t.message ?: "listCalendars failed", null)
                    }
                }
                "listEvents" -> {
                    val calId = call.argument<String>("calendarId") ?: ""
                    val startMs = call.argument<Long>("startMs") ?: 0L
                    val endMs = call.argument<Long>("endMs") ?: 0L
                    try {
                        result.success(listEvents(calId, startMs, endMs))
                    } catch (t: Throwable) {
                        result.error("CAL_ERR", t.message ?: "listEvents failed", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Returns List<Map<String, String>> — [{id, name}]
    private fun listCalendars(): List<Map<String, String>> {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME
        )
        val cr = contentResolver ?: return emptyList()
        val results = mutableListOf<Map<String, String>>()
        var cursor: android.database.Cursor? = null
        try {
            cursor = cr.query(
                CalendarContract.Calendars.CONTENT_URI,
                projection,
                null, null, null
            ) ?: return emptyList()
            while (cursor.moveToNext()) {
                try {
                    val id = cursor.getLong(0).toString()
                    val name = cursor.getString(1) ?: continue
                    results.add(mapOf("id" to id, "name" to name))
                } catch (_: Throwable) {}
            }
        } finally {
            cursor?.close()
        }
        return results
    }

    // Returns List<Map<String, Any?>> — [{id, title, startMs, allDay}]
    private fun listEvents(calendarId: String, startMs: Long, endMs: Long): List<Map<String, Any?>> {
        // Minimal safe projection — excludes CUSTOM_APP_URI, EVENT_END_TIMEZONE,
        // AVAILABILITY, STATUS, IS_PRIMARY which crash Samsung's CalendarProvider
        val projection = arrayOf(
            CalendarContract.Events._ID,
            CalendarContract.Events.TITLE,
            CalendarContract.Events.DTSTART,
            CalendarContract.Events.ALL_DAY
        )
        val selection = "(${CalendarContract.Events.CALENDAR_ID} = ?) AND " +
                "(${CalendarContract.Events.DTSTART} >= ?) AND " +
                "(${CalendarContract.Events.DTSTART} <= ?) AND " +
                "(${CalendarContract.Events.DELETED} != 1)"
        val selArgs = arrayOf(calendarId, startMs.toString(), endMs.toString())

        val cr = contentResolver ?: return emptyList()
        val results = mutableListOf<Map<String, Any?>>()
        var cursor: android.database.Cursor? = null
        try {
            cursor = cr.query(
                CalendarContract.Events.CONTENT_URI,
                projection,
                selection,
                selArgs,
                "${CalendarContract.Events.DTSTART} ASC"
            ) ?: return emptyList()
            while (cursor.moveToNext()) {
                try {
                    val id = cursor.getLong(0).toString()
                    val title = cursor.getString(1) ?: "(제목 없음)"
                    val startEpoch = cursor.getLong(2)
                    val allDay = cursor.getInt(3) != 0
                    results.add(mapOf(
                        "id" to id,
                        "title" to title,
                        "startMs" to startEpoch,
                        "allDay" to allDay
                    ))
                } catch (_: Throwable) {}
            }
        } finally {
            cursor?.close()
        }
        return results
    }

    private fun installApk(filePath: String) {
        val file = File(filePath)
        val intent = Intent(Intent.ACTION_VIEW)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )
            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } else {
            intent.setDataAndType(
                Uri.fromFile(file),
                "application/vnd.android.package-archive"
            )
        }

        startActivity(intent)
    }
}
