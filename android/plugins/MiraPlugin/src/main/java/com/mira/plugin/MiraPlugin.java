package com.mira.plugin;

import android.Manifest;
import android.app.Activity;
import android.app.admin.DevicePolicyManager;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.net.Uri;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Handler;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Environment;
import android.os.StatFs;
import android.provider.CallLog;
import android.provider.ContactsContract;
import android.provider.MediaStore;
import android.provider.Settings;
import android.provider.Telephony;
import android.provider.CalendarContract;
import android.telephony.TelephonyManager;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.location.Address;
import android.location.Geocoder;
import android.location.Location;
import android.location.LocationManager;
import android.accounts.Account;
import android.accounts.AccountManager;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.SortedMap;
import java.util.TreeMap;

public class MiraPlugin extends GodotPlugin {

    private static final String TAG = "MiraPlugin";
    private static final String CHANNEL_ID = "mira_channel";
    private static final int DEVICE_ADMIN_REQUEST = 9001;

    private Activity activity;
    private Context context;
    private int stepCountCache = -1;

    public MiraPlugin(Godot godot) {
        super(godot);
        activity = godot.getActivity();
        context = activity.getApplicationContext();
        createNotificationChannel();
        initStepCounter();
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "MiraPlugin";
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID, "Мира", NotificationManager.IMPORTANCE_HIGH);
            channel.setDescription("Уведомления от Миры");
            NotificationManager nm = context.getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(channel);
        }
    }

    private void initStepCounter() {
        try {
            SensorManager sm = (SensorManager) context.getSystemService(Context.SENSOR_SERVICE);
            if (sm == null) return;
            Sensor stepSensor = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER);
            if (stepSensor == null) return;
            sm.registerListener(new SensorEventListener() {
                @Override
                public void onSensorChanged(SensorEvent event) {
                    stepCountCache = (int) event.values[0];
                }
                @Override
                public void onAccuracyChanged(Sensor sensor, int accuracy) {}
            }, stepSensor, SensorManager.SENSOR_DELAY_NORMAL);
        } catch (Exception e) {
            Log.e(TAG, "initStepCounter: " + e.getMessage());
        }
    }

    // ── Батарея ────────────────────────────────────────────────────────────

    @UsedByGodot
    public int getBatteryLevel() {
        BatteryManager bm = (BatteryManager) context.getSystemService(Context.BATTERY_SERVICE);
        if (bm != null) return bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
        return -1;
    }

    @UsedByGodot
    public boolean isCharging() {
        try {
            IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
            Intent status = context.registerReceiver(null, filter);
            if (status != null) {
                int plugged = status.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1);
                return plugged == BatteryManager.BATTERY_PLUGGED_AC
                    || plugged == BatteryManager.BATTERY_PLUGGED_USB
                    || plugged == BatteryManager.BATTERY_PLUGGED_WIRELESS;
            }
        } catch (Exception e) {
            Log.e(TAG, "isCharging: " + e.getMessage());
        }
        return false;
    }

    // ── Сеть ───────────────────────────────────────────────────────────────

    @UsedByGodot
    public String getWifiSSID() {
        try {
            WifiManager wm = (WifiManager) context.getSystemService(Context.WIFI_SERVICE);
            if (wm != null) {
                WifiInfo info = wm.getConnectionInfo();
                if (info != null) {
                    String ssid = info.getSSID();
                    if (ssid != null) return ssid.replace("\"", "");
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "getWifiSSID: " + e.getMessage());
        }
        return "";
    }

    @UsedByGodot
    public String getNetworkOperator() {
        try {
            TelephonyManager tm = (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);
            if (tm != null) {
                String name = tm.getNetworkOperatorName();
                return name != null ? name : "";
            }
        } catch (Exception e) {
            Log.e(TAG, "getNetworkOperator: " + e.getMessage());
        }
        return "";
    }

    @UsedByGodot
    public boolean isAirplaneModeOn() {
        try {
            return Settings.Global.getInt(context.getContentResolver(),
                Settings.Global.AIRPLANE_MODE_ON, 0) != 0;
        } catch (Exception e) {
            Log.e(TAG, "isAirplaneModeOn: " + e.getMessage());
        }
        return false;
    }

    // ── Телефон ────────────────────────────────────────────────────────────

    @UsedByGodot
    public String getPhoneNumber() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE)
                != PackageManager.PERMISSION_GRANTED) return "";
        try {
            TelephonyManager tm = (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);
            if (tm != null) {
                String number = tm.getLine1Number();
                return number != null ? number : "";
            }
        } catch (Exception e) {
            Log.e(TAG, "getPhoneNumber: " + e.getMessage());
        }
        return "";
    }

    @UsedByGodot
    public int getCallState() {
        try {
            TelephonyManager tm = (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);
            if (tm != null) return tm.getCallState();
            // 0=IDLE, 1=RINGING, 2=OFFHOOK
        } catch (Exception e) {
            Log.e(TAG, "getCallState: " + e.getMessage());
        }
        return 0;
    }

    // ── Контакты ───────────────────────────────────────────────────────────

    @UsedByGodot
    public String[] getContacts() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CONTACTS)
                != PackageManager.PERMISSION_GRANTED) return new String[0];
        List<String> result = new ArrayList<>();
        try {
            Cursor cursor = context.getContentResolver().query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                new String[]{
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                }, null, null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC");
            if (cursor != null) {
                while (cursor.moveToNext()) {
                    String name = cursor.getString(0);
                    String phone = cursor.getString(1);
                    if (name != null && phone != null) result.add(name + "|||" + phone);
                }
                cursor.close();
            }
        } catch (Exception e) {
            Log.e(TAG, "getContacts: " + e.getMessage());
        }
        return result.toArray(new String[0]);
    }

    // ── Журнал звонков ─────────────────────────────────────────────────────

    @UsedByGodot
    public String getLastCallName() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG)
                != PackageManager.PERMISSION_GRANTED) return "";
        try {
            Cursor cursor = context.getContentResolver().query(
                CallLog.Calls.CONTENT_URI,
                new String[]{CallLog.Calls.CACHED_NAME, CallLog.Calls.NUMBER},
                null, null, CallLog.Calls.DATE + " DESC LIMIT 1");
            if (cursor != null && cursor.moveToFirst()) {
                String name = cursor.getString(0);
                String number = cursor.getString(1);
                cursor.close();
                return (name != null && !name.isEmpty()) ? name : number;
            }
            if (cursor != null) cursor.close();
        } catch (Exception e) {
            Log.e(TAG, "getLastCallName: " + e.getMessage());
        }
        return "";
    }

    @UsedByGodot
    public String getLastCallTimeAgo() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG)
                != PackageManager.PERMISSION_GRANTED) return "";
        try {
            Cursor cursor = context.getContentResolver().query(
                CallLog.Calls.CONTENT_URI,
                new String[]{CallLog.Calls.DATE},
                null, null, CallLog.Calls.DATE + " DESC LIMIT 1");
            if (cursor != null && cursor.moveToFirst()) {
                long date = cursor.getLong(0);
                cursor.close();
                long diff = System.currentTimeMillis() - date;
                long hours = diff / 3600000;
                long mins = (diff % 3600000) / 60000;
                if (hours > 0) return hours + " ч. назад";
                return mins + " мин. назад";
            }
            if (cursor != null) cursor.close();
        } catch (Exception e) {
            Log.e(TAG, "getLastCallTimeAgo: " + e.getMessage());
        }
        return "";
    }

    @UsedByGodot
    public int getLastCallDirection() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG)
                != PackageManager.PERMISSION_GRANTED) return -1;
        try {
            Cursor cursor = context.getContentResolver().query(
                CallLog.Calls.CONTENT_URI,
                new String[]{CallLog.Calls.TYPE},
                null, null, CallLog.Calls.DATE + " DESC LIMIT 1");
            if (cursor != null && cursor.moveToFirst()) {
                int type = cursor.getInt(0);
                cursor.close();
                return type; // 1=incoming, 2=outgoing, 3=missed
            }
            if (cursor != null) cursor.close();
        } catch (Exception e) {
            Log.e(TAG, "getLastCallDirection: " + e.getMessage());
        }
        return -1;
    }

    @UsedByGodot
    public int getCallCountToday() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG)
                != PackageManager.PERMISSION_GRANTED) return 0;
        try {
            Calendar cal = Calendar.getInstance();
            cal.set(Calendar.HOUR_OF_DAY, 0);
            cal.set(Calendar.MINUTE, 0);
            cal.set(Calendar.SECOND, 0);
            Cursor cursor = context.getContentResolver().query(
                CallLog.Calls.CONTENT_URI,
                new String[]{CallLog.Calls._ID},
                CallLog.Calls.DATE + " >= ?",
                new String[]{String.valueOf(cal.getTimeInMillis())}, null);
            int count = 0;
            if (cursor != null) { count = cursor.getCount(); cursor.close(); }
            return count;
        } catch (Exception e) {
            Log.e(TAG, "getCallCountToday: " + e.getMessage());
        }
        return 0;
    }

    @UsedByGodot
    public int getMissedCallsCount() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG)
                != PackageManager.PERMISSION_GRANTED) return 0;
        try {
            Cursor cursor = context.getContentResolver().query(
                CallLog.Calls.CONTENT_URI,
                new String[]{CallLog.Calls._ID},
                CallLog.Calls.TYPE + " = ?",
                new String[]{String.valueOf(CallLog.Calls.MISSED_TYPE)}, null);
            int count = 0;
            if (cursor != null) { count = cursor.getCount(); cursor.close(); }
            return count;
        } catch (Exception e) {
            Log.e(TAG, "getMissedCallsCount: " + e.getMessage());
        }
        return 0;
    }

    // ── SMS ────────────────────────────────────────────────────────────────

    @UsedByGodot
    public String getSmsSnippet() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS)
                != PackageManager.PERMISSION_GRANTED) return "";
        try {
            Cursor cursor = context.getContentResolver().query(
                Telephony.Sms.CONTENT_URI,
                new String[]{Telephony.Sms.BODY, Telephony.Sms.DATE},
                null, null, Telephony.Sms.DATE + " DESC LIMIT 1");
            if (cursor != null && cursor.moveToFirst()) {
                String body = cursor.getString(0);
                cursor.close();
                if (body != null && body.length() > 60) return body.substring(0, 60) + "...";
                return body != null ? body : "";
            }
            if (cursor != null) cursor.close();
        } catch (Exception e) {
            Log.e(TAG, "getSmsSnippet: " + e.getMessage());
        }
        return "";
    }

    // ── Местоположение ─────────────────────────────────────────────────────

    @UsedByGodot
    public String getCity() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) return "";
        try {
            LocationManager lm = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
            if (lm == null) return "";
            Location location = null;
            for (String provider : Arrays.asList(
                    LocationManager.GPS_PROVIDER,
                    LocationManager.NETWORK_PROVIDER,
                    LocationManager.PASSIVE_PROVIDER)) {
                Location l = lm.getLastKnownLocation(provider);
                if (l != null) { location = l; break; }
            }
            if (location == null) return "";
            Geocoder geocoder = new Geocoder(context, new Locale("ru"));
            List<Address> addresses = geocoder.getFromLocation(
                location.getLatitude(), location.getLongitude(), 1);
            if (addresses != null && !addresses.isEmpty()) {
                String city = addresses.get(0).getLocality();
                return city != null ? city : "";
            }
        } catch (Exception e) {
            Log.e(TAG, "getCity: " + e.getMessage());
        }
        return "";
    }

    // ── Аккаунты / Календарь ───────────────────────────────────────────────

    @UsedByGodot
    public String getGoogleAccount() {
        try {
            AccountManager am = AccountManager.get(context);
            Account[] accounts = am.getAccountsByType("com.google");
            if (accounts.length > 0) return accounts[0].name;
        } catch (Exception e) {
            Log.e(TAG, "getGoogleAccount: " + e.getMessage());
        }
        return "";
    }

    @UsedByGodot
    public String getNextCalendarEvent() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR)
                != PackageManager.PERMISSION_GRANTED) return "";
        try {
            long now = System.currentTimeMillis();
            long tomorrow = now + 86400000L * 2;
            Cursor cursor = context.getContentResolver().query(
                CalendarContract.Events.CONTENT_URI,
                new String[]{CalendarContract.Events.TITLE, CalendarContract.Events.DTSTART},
                CalendarContract.Events.DTSTART + " >= ? AND " +
                CalendarContract.Events.DTSTART + " <= ?",
                new String[]{String.valueOf(now), String.valueOf(tomorrow)},
                CalendarContract.Events.DTSTART + " ASC LIMIT 1");
            if (cursor != null && cursor.moveToFirst()) {
                String title = cursor.getString(0);
                cursor.close();
                return title != null ? title : "";
            }
            if (cursor != null) cursor.close();
        } catch (Exception e) {
            Log.e(TAG, "getNextCalendarEvent: " + e.getMessage());
        }
        return "";
    }

    // ── Приложения / Статистика ────────────────────────────────────────────

    @UsedByGodot
    public String getMostUsedApp() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) return "";
        try {
            UsageStatsManager usm = (UsageStatsManager) context.getSystemService(Context.USAGE_STATS_SERVICE);
            if (usm == null) return "";
            long end = System.currentTimeMillis();
            long start = end - 7 * 24 * 60 * 60 * 1000L;
            List<UsageStats> stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_WEEKLY, start, end);
            if (stats == null || stats.isEmpty()) return "";
            UsageStats top = Collections.max(stats,
                Comparator.comparingLong(UsageStats::getTotalTimeInForeground));
            PackageManager pm = context.getPackageManager();
            try {
                ApplicationInfo info = pm.getApplicationInfo(top.getPackageName(), 0);
                return pm.getApplicationLabel(info).toString();
            } catch (Exception e) {
                return top.getPackageName();
            }
        } catch (Exception e) {
            Log.e(TAG, "getMostUsedApp: " + e.getMessage());
        }
        return "";
    }

    @UsedByGodot
    public String[] getInstalledApps() {
        List<String> apps = new ArrayList<>();
        try {
            PackageManager pm = context.getPackageManager();
            List<ApplicationInfo> packages = pm.getInstalledApplications(PackageManager.GET_META_DATA);
            for (ApplicationInfo app : packages) {
                if ((app.flags & ApplicationInfo.FLAG_SYSTEM) == 0)
                    apps.add(pm.getApplicationLabel(app).toString());
            }
        } catch (Exception e) {
            Log.e(TAG, "getInstalledApps: " + e.getMessage());
        }
        return apps.toArray(new String[0]);
    }

    @UsedByGodot
    public int getUnlockCountToday() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) return 0;
        try {
            UsageStatsManager usm = (UsageStatsManager) context.getSystemService(Context.USAGE_STATS_SERVICE);
            if (usm == null) return 0;
            Calendar cal = Calendar.getInstance();
            cal.set(Calendar.HOUR_OF_DAY, 0);
            cal.set(Calendar.MINUTE, 0);
            cal.set(Calendar.SECOND, 0);
            long start = cal.getTimeInMillis();
            long end = System.currentTimeMillis();
            UsageEvents events = usm.queryEvents(start, end);
            int count = 0;
            UsageEvents.Event event = new UsageEvents.Event();
            while (events.hasNextEvent()) {
                events.getNextEvent(event);
                if (event.getEventType() == UsageEvents.Event.KEYGUARD_HIDDEN
                        || event.getEventType() == UsageEvents.Event.SCREEN_INTERACTIVE) {
                    count++;
                }
            }
            return count;
        } catch (Exception e) {
            Log.e(TAG, "getUnlockCountToday: " + e.getMessage());
        }
        return 0;
    }

    @UsedByGodot
    public String getCurrentForegroundApp() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) return "";
        try {
            UsageStatsManager usm = (UsageStatsManager) context.getSystemService(Context.USAGE_STATS_SERVICE);
            if (usm == null) return "";
            long end = System.currentTimeMillis();
            long start = end - 15000;
            UsageEvents events = usm.queryEvents(start, end);
            UsageEvents.Event event = new UsageEvents.Event();
            String lastPkg = "";
            while (events.hasNextEvent()) {
                events.getNextEvent(event);
                if (event.getEventType() == UsageEvents.Event.MOVE_TO_FOREGROUND)
                    lastPkg = event.getPackageName();
            }
            if (!lastPkg.isEmpty()) {
                PackageManager pm = context.getPackageManager();
                try {
                    ApplicationInfo info = pm.getApplicationInfo(lastPkg, 0);
                    return pm.getApplicationLabel(info).toString();
                } catch (Exception e2) { return lastPkg; }
            }
        } catch (Exception e) {
            Log.e(TAG, "getCurrentForegroundApp: " + e.getMessage());
        }
        return "";
    }

    // ── Медиа ──────────────────────────────────────────────────────────────

    @UsedByGodot
    public String getRandomGalleryPhotoPath() {
        try {
            Cursor cursor = context.getContentResolver().query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                new String[]{MediaStore.Images.Media.DATA},
                null, null, "RANDOM() LIMIT 1");
            if (cursor != null && cursor.moveToFirst()) {
                String path = cursor.getString(0);
                cursor.close();
                return path != null ? path : "";
            }
            if (cursor != null) cursor.close();
        } catch (Exception e) {
            Log.e(TAG, "getRandomGalleryPhotoPath: " + e.getMessage());
        }
        return "";
    }

    @UsedByGodot
    public String getRandomVideoPath() {
        try {
            Cursor cursor = context.getContentResolver().query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                new String[]{MediaStore.Video.Media.DATA},
                MediaStore.Video.Media.DURATION + " >= ?",
                new String[]{"5000"},
                "RANDOM() LIMIT 1");
            if (cursor != null && cursor.moveToFirst()) {
                String path = cursor.getString(0);
                cursor.close();
                return path != null ? path : "";
            }
            if (cursor != null) cursor.close();
        } catch (Exception e) {
            Log.e(TAG, "getRandomVideoPath: " + e.getMessage());
        }
        return "";
    }

    // ── Звук / Режим ───────────────────────────────────────────────────────

    @UsedByGodot
    public int getRingerMode() {
        try {
            AudioManager am = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
            if (am != null) return am.getRingerMode();
            // 0=SILENT, 1=VIBRATE, 2=NORMAL
        } catch (Exception e) {
            Log.e(TAG, "getRingerMode: " + e.getMessage());
        }
        return -1;
    }

    @UsedByGodot
    public int getAudioAmplitude() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) return -1;
        try {
            int bufferSize = AudioRecord.getMinBufferSize(8000,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
            if (bufferSize <= 0) return -1;
            AudioRecord recorder = new AudioRecord(MediaRecorder.AudioSource.MIC,
                8000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, bufferSize);
            recorder.startRecording();
            short[] buffer = new short[bufferSize];
            recorder.read(buffer, 0, bufferSize);
            recorder.stop();
            recorder.release();
            long sum = 0;
            for (short s : buffer) sum += (long) s * s;
            return (int) Math.sqrt((double) sum / buffer.length);
        } catch (Exception e) {
            Log.e(TAG, "getAudioAmplitude: " + e.getMessage());
        }
        return -1;
    }

    // ── Экран / Устройство ─────────────────────────────────────────────────

    @UsedByGodot
    public int getScreenBrightness() {
        try {
            return Settings.System.getInt(context.getContentResolver(),
                Settings.System.SCREEN_BRIGHTNESS);
        } catch (Exception e) {
            Log.e(TAG, "getScreenBrightness: " + e.getMessage());
        }
        return -1;
    }

    @UsedByGodot
    public long getFreeStorageMB() {
        try {
            StatFs stat = new StatFs(Environment.getDataDirectory().getPath());
            return stat.getAvailableBlocksLong() * stat.getBlockSizeLong() / (1024 * 1024);
        } catch (Exception e) {
            Log.e(TAG, "getFreeStorageMB: " + e.getMessage());
        }
        return -1;
    }

    @UsedByGodot
    public long getTotalStorageMB() {
        try {
            StatFs stat = new StatFs(Environment.getDataDirectory().getPath());
            return stat.getBlockCountLong() * stat.getBlockSizeLong() / (1024 * 1024);
        } catch (Exception e) {
            Log.e(TAG, "getTotalStorageMB: " + e.getMessage());
        }
        return -1;
    }

    @UsedByGodot
    public String getSystemLanguage() {
        return Locale.getDefault().getDisplayLanguage();
    }

    @UsedByGodot
    public String getTimezone() {
        return java.util.TimeZone.getDefault().getID();
    }

    // ── Bluetooth ──────────────────────────────────────────────────────────

    @UsedByGodot
    public String getBluetoothDeviceName() {
        try {
            BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
            if (adapter == null || !adapter.isEnabled()) return "";
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT)
                        != PackageManager.PERMISSION_GRANTED) return "";
            }
            Set<BluetoothDevice> paired = adapter.getBondedDevices();
            if (paired != null && !paired.isEmpty()) {
                BluetoothDevice first = paired.iterator().next();
                String name = first.getName();
                return name != null ? name : "";
            }
        } catch (Exception e) {
            Log.e(TAG, "getBluetoothDeviceName: " + e.getMessage());
        }
        return "";
    }

    @UsedByGodot
    public String[] getBluetoothDevices() {
        List<String> result = new ArrayList<>();
        try {
            BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
            if (adapter == null || !adapter.isEnabled()) return new String[0];
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT)
                        != PackageManager.PERMISSION_GRANTED) return new String[0];
            }
            Set<BluetoothDevice> paired = adapter.getBondedDevices();
            if (paired != null) {
                for (BluetoothDevice device : paired) {
                    String name = device.getName();
                    if (name != null) result.add(name);
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "getBluetoothDevices: " + e.getMessage());
        }
        return result.toArray(new String[0]);
    }

    // ── Шагомер ────────────────────────────────────────────────────────────

    @UsedByGodot
    public int getStepCount() {
        return stepCountCache;
    }

    // ── Accessibility / Уведомления ────────────────────────────────────────

    @UsedByGodot
    public String[] getRecentNotifications() {
        List<String> stored = MiraNotificationService.getStoredNotifications();
        return stored.toArray(new String[0]);
    }

    @UsedByGodot
    public String[] getCapturedTexts() {
        return MiraAccessibilityService.getCapturedTexts().toArray(new String[0]);
    }

    @UsedByGodot
    public String getLastDeleteIntentApp() {
        return MiraAccessibilityService.getLastDeleteIntent();
    }

    // ── Камера ─────────────────────────────────────────────────────────────

    @UsedByGodot
    public String takeFrontCameraPhoto() {
        try {
            File photoFile = new File(context.getFilesDir(), "mira_capture.jpg");
            MiraCameraCapture.takeFrontPhoto(activity, photoFile.getAbsolutePath());
            return photoFile.getAbsolutePath();
        } catch (Exception e) {
            Log.e(TAG, "takeFrontCameraPhoto: " + e.getMessage());
        }
        return "";
    }

    // ── Уведомления / Управление ───────────────────────────────────────────

    @UsedByGodot
    public void sendNotification(String title, String body) {
        try {
            NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true);
            NotificationManager nm =
                (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null) nm.notify((int) System.currentTimeMillis(), builder.build());
        } catch (Exception e) {
            Log.e(TAG, "sendNotification: " + e.getMessage());
        }
    }

    @UsedByGodot
    public void scheduleNotification(int delaySeconds, int requestCode, String title, String body) {
        try {
            AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            Intent intent = new Intent(context, MiraAlarmReceiver.class);
            intent.putExtra("title", title);
            intent.putExtra("body", body);
            PendingIntent pi = PendingIntent.getBroadcast(context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            long triggerAt = System.currentTimeMillis() + (long) delaySeconds * 1000L;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi);
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi);
            }
        } catch (Exception e) {
            Log.e(TAG, "scheduleNotification: " + e.getMessage());
        }
    }

    @UsedByGodot
    public void cancelScheduledNotification(int requestCode) {
        try {
            AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            Intent intent = new Intent(context, MiraAlarmReceiver.class);
            PendingIntent pi = PendingIntent.getBroadcast(context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            am.cancel(pi);
        } catch (Exception e) {
            Log.e(TAG, "cancelScheduledNotification: " + e.getMessage());
        }
    }


    // ── Фонарик ────────────────────────────────────────────────────────────

    @UsedByGodot
    public void flashTorch(int durationMs) {
        try {
            CameraManager cm = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
            if (cm == null) return;
            for (String id : cm.getCameraIdList()) {
                Boolean hasFlash = cm.getCameraCharacteristics(id)
                    .get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
                if (!Boolean.TRUE.equals(hasFlash)) continue;
                final String camId = id;
                cm.setTorchMode(camId, true);
                new Handler(Looper.getMainLooper()).postDelayed(() -> {
                    try { cm.setTorchMode(camId, false); } catch (Exception ignored) {}
                }, durationMs);
                break;
            }
        } catch (Exception e) {
            Log.e(TAG, "flashTorch: " + e.getMessage());
        }
    }

    // ── SMS ────────────────────────────────────────────────────────────────

    @UsedByGodot
    public String[] getRecentSms(int limit) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS)
                != PackageManager.PERMISSION_GRANTED) return new String[0];
        List<String> results = new ArrayList<>();
        try {
            Cursor cursor = context.getContentResolver().query(
                Telephony.Sms.CONTENT_URI,
                new String[]{Telephony.Sms.ADDRESS, Telephony.Sms.BODY},
                null, null, Telephony.Sms.DATE + " DESC");
            if (cursor != null) {
                int count = 0;
                while (cursor.moveToNext() && count < limit) {
                    String address = cursor.getString(0);
                    String body    = cursor.getString(1);
                    if (address == null || body == null || body.trim().isEmpty()) continue;
                    String name = _lookupContactName(address);
                    String sender = (name != null && !name.isEmpty()) ? name : address;
                    if (body.length() > 80) body = body.substring(0, 80) + "...";
                    results.add(sender + "|||" + body.trim());
                    count++;
                }
                cursor.close();
            }
        } catch (Exception e) {
            Log.e(TAG, "getRecentSms: " + e.getMessage());
        }
        return results.toArray(new String[0]);
    }

    private String _lookupContactName(String phoneNumber) {
        try {
            Uri uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneNumber));
            Cursor c = context.getContentResolver().query(
                uri, new String[]{ContactsContract.PhoneLookup.DISPLAY_NAME}, null, null, null);
            if (c != null && c.moveToFirst()) {
                String name = c.getString(0);
                c.close();
                return name;
            }
            if (c != null) c.close();
        } catch (Exception ignored) {}
        return null;
    }

    // ── Вибрация по паттерну ───────────────────────────────────────────────

    @UsedByGodot
    public void vibratePattern(int[] durationsMs) {
        try {
            Vibrator v = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
            if (v == null) return;
            long[] timings = new long[durationsMs.length];
            int[] amplitudes = new int[durationsMs.length];
            for (int i = 0; i < durationsMs.length; i++) {
                timings[i] = durationsMs[i];
                amplitudes[i] = (i % 2 == 0) ? 0 : 255;
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                v.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1));
            } else {
                v.vibrate(timings, -1);
            }
        } catch (Exception e) {
            Log.e(TAG, "vibratePattern: " + e.getMessage());
        }
    }


    // ── Оверлей поверх всех приложений (SYSTEM_ALERT_WINDOW) ────────────────

    @UsedByGodot
    public void showOverlay(String message) {
        try {
            Intent intent = new Intent(context, MiraOverlayService.class);
            intent.putExtra("message", message != null ? message : "Я здесь.");
            context.startService(intent);
        } catch (Exception e) {
            Log.e(TAG, "showOverlay: " + e.getMessage());
        }
    }

    @UsedByGodot
    public void hideOverlay() {
        try {
            context.stopService(new Intent(context, MiraOverlayService.class));
        } catch (Exception e) {
            Log.e(TAG, "hideOverlay: " + e.getMessage());
        }
    }

    @UsedByGodot
    public boolean canDrawOverlays() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            return android.provider.Settings.canDrawOverlays(context);
        }
        return true;
    }

    @UsedByGodot
    public void requestOverlayPermission() {
        try {
            Intent intent = new Intent(
                android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                android.net.Uri.parse("package:" + context.getPackageName())
            );
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception e) {
            Log.e(TAG, "requestOverlayPermission: " + e.getMessage());
        }
    }

    @UsedByGodot
    public String getPendingOverlayMessage() {
        String msg = MiraAccessibilityService.pendingOverlayMessage;
        MiraAccessibilityService.pendingOverlayMessage = "";
        return msg != null ? msg : "";
    }

    // ── Конец методов оверлея ────────────────────────────────────────────────

    @UsedByGodot
    public void lockScreen() {
        try {
            DevicePolicyManager dpm = (DevicePolicyManager)
                context.getSystemService(Context.DEVICE_POLICY_SERVICE);
            if (dpm != null && dpm.isAdminActive(
                    new ComponentName(context, MiraDeviceAdminReceiver.class))) {
                dpm.lockNow();
            }
        } catch (Exception e) {
            Log.e(TAG, "lockScreen: " + e.getMessage());
        }
    }

    @UsedByGodot
    public void requestDeviceAdmin() {
        try {
            ComponentName adminComponent =
                new ComponentName(context, MiraDeviceAdminReceiver.class);
            Intent intent = new Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN);
            intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent);
            intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Мира использует права администратора для защиты твоих воспоминаний");
            activity.startActivityForResult(intent, DEVICE_ADMIN_REQUEST);
        } catch (Exception e) {
            Log.e(TAG, "requestDeviceAdmin: " + e.getMessage());
        }
    }

    // ── Открытие системных настроек ────────────────────────────────────────

    @UsedByGodot
    public void openUsageAccessSettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception e) {
            Log.e(TAG, "openUsageAccessSettings: " + e.getMessage());
        }
    }

    @UsedByGodot
    public void openNotificationListenerSettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception e) {
            Log.e(TAG, "openNotificationListenerSettings: " + e.getMessage());
        }
    }

    @UsedByGodot
    public void openAccessibilitySettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception e) {
            Log.e(TAG, "openAccessibilitySettings: " + e.getMessage());
        }
    }

    // ── Смена иконки ───────────────────────────────────────────────────────

    @UsedByGodot
    public void setAppAlias(String aliasName) {
        try {
            PackageManager pm = context.getPackageManager();
            String appPackage = context.getPackageName();
            String pluginPackage = "com.mira.plugin";
            ComponentName normalAlias = new ComponentName(appPackage, pluginPackage + ".MiraAlias");
            ComponentName horrorAlias = new ComponentName(appPackage, pluginPackage + ".HorrorAlias");
            if (aliasName.equals("horror")) {
                pm.setComponentEnabledSetting(normalAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP);
                pm.setComponentEnabledSetting(horrorAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP);
            } else {
                pm.setComponentEnabledSetting(horrorAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP);
                pm.setComponentEnabledSetting(normalAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP);
            }
        } catch (Exception e) {
            Log.e(TAG, "setAppAlias: " + e.getMessage());
        }
    }
}
