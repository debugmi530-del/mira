package com.mira.plugin;

import android.Manifest;
import android.app.Activity;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.BatteryManager;
import android.os.Build;
import android.provider.CallLog;
import android.provider.ContactsContract;
import android.provider.Telephony;
import android.provider.CalendarContract;
import android.telephony.TelephonyManager;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.location.Address;
import android.location.Geocoder;
import android.location.Location;
import android.location.LocationManager;
import android.accounts.Account;
import android.accounts.AccountManager;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.graphics.ImageFormat;
import android.provider.MediaStore;
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
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.SortedMap;
import java.util.TreeMap;

public class MiraPlugin extends GodotPlugin {

    private static final String TAG = "MiraPlugin";
    private static final String CHANNEL_ID = "mira_channel";
    private static final int DEVICE_ADMIN_REQUEST = 9001;

    private Activity activity;
    private Context context;

    public MiraPlugin(Godot godot) {
        super(godot);
        activity = godot.getActivity();
        context = activity.getApplicationContext();
        createNotificationChannel();
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

    @UsedByGodot
    public int getBatteryLevel() {
        BatteryManager bm = (BatteryManager) context.getSystemService(Context.BATTERY_SERVICE);
        if (bm != null) {
            return bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
        }
        return -1;
    }

    @UsedByGodot
    public String getWifiSSID() {
        try {
            WifiManager wm = (WifiManager) context.getSystemService(Context.WIFI_SERVICE);
            if (wm != null) {
                WifiInfo info = wm.getConnectionInfo();
                if (info != null) {
                    String ssid = info.getSSID();
                    if (ssid != null) {
                        return ssid.replace("\"", "");
                    }
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
    public String[] getContacts() {
        List<String[]> contacts = new ArrayList<>();
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CONTACTS)
                != PackageManager.PERMISSION_GRANTED) {
            return new String[0];
        }
        try {
            Cursor cursor = context.getContentResolver().query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                new String[]{
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                }, null, null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
            );
            if (cursor != null) {
                while (cursor.moveToNext()) {
                    String name = cursor.getString(0);
                    String phone = cursor.getString(1);
                    if (name != null && phone != null) {
                        contacts.add(new String[]{name, phone});
                    }
                }
                cursor.close();
            }
        } catch (Exception e) {
            Log.e(TAG, "getContacts: " + e.getMessage());
        }
        List<String> result = new ArrayList<>();
        for (String[] c : contacts) {
            result.add(c[0] + "|||" + c[1]);
        }
        return result.toArray(new String[0]);
    }

    @UsedByGodot
    public String getLastCallName() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG)
                != PackageManager.PERMISSION_GRANTED) return "";
        try {
            Cursor cursor = context.getContentResolver().query(
                CallLog.Calls.CONTENT_URI,
                new String[]{CallLog.Calls.CACHED_NAME, CallLog.Calls.NUMBER, CallLog.Calls.DATE},
                null, null, CallLog.Calls.DATE + " DESC LIMIT 1"
            );
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
                null, null, CallLog.Calls.DATE + " DESC LIMIT 1"
            );
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
    public String getSmsSnippet() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS)
                != PackageManager.PERMISSION_GRANTED) return "";
        try {
            Cursor cursor = context.getContentResolver().query(
                Telephony.Sms.CONTENT_URI,
                new String[]{Telephony.Sms.BODY, Telephony.Sms.DATE},
                null, null, Telephony.Sms.DATE + " DESC LIMIT 1"
            );
            if (cursor != null && cursor.moveToFirst()) {
                String body = cursor.getString(0);
                cursor.close();
                if (body != null && body.length() > 60) {
                    return body.substring(0, 60) + "...";
                }
                return body != null ? body : "";
            }
            if (cursor != null) cursor.close();
        } catch (Exception e) {
            Log.e(TAG, "getSmsSnippet: " + e.getMessage());
        }
        return "";
    }

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

    @UsedByGodot
    public String getGoogleAccount() {
        try {
            AccountManager am = AccountManager.get(context);
            Account[] accounts = am.getAccountsByType("com.google");
            if (accounts.length > 0) {
                return accounts[0].name;
            }
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
                CalendarContract.Events.DTSTART + " ASC LIMIT 1"
            );
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

    @UsedByGodot
    public String getMostUsedApp() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) return "";
        try {
            UsageStatsManager usm = (UsageStatsManager) context.getSystemService(
                Context.USAGE_STATS_SERVICE);
            if (usm == null) return "";
            long end = System.currentTimeMillis();
            long start = end - 7 * 24 * 60 * 60 * 1000L;
            List<UsageStats> stats = usm.queryUsageStats(
                UsageStatsManager.INTERVAL_WEEKLY, start, end);
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
                if ((app.flags & ApplicationInfo.FLAG_SYSTEM) == 0) {
                    apps.add(pm.getApplicationLabel(app).toString());
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "getInstalledApps: " + e.getMessage());
        }
        return apps.toArray(new String[0]);
    }

    @UsedByGodot
    public String getRandomGalleryPhotoPath() {
        try {
            Cursor cursor = context.getContentResolver().query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                new String[]{MediaStore.Images.Media.DATA},
                null, null, "RANDOM() LIMIT 1"
            );
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
    public int getUnlockCountToday() {
        return -1;
    }

    @UsedByGodot
    public String[] getRecentNotifications() {
        List<String> stored = MiraNotificationService.getStoredNotifications();
        return stored.toArray(new String[0]);
    }

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
            if (nm != null) {
                nm.notify((int) System.currentTimeMillis(), builder.build());
            }
        } catch (Exception e) {
            Log.e(TAG, "sendNotification: " + e.getMessage());
        }
    }

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

    @UsedByGodot
    public void setAppAlias(String aliasName) {
        try {
            PackageManager pm = context.getPackageManager();
            // Aliases are declared in the plugin manifest (package com.mira.plugin),
            // so their full class names use that package after manifest merge
            String pluginPackage = "com.mira.plugin";
            ComponentName normalAlias =
                new ComponentName(pluginPackage, pluginPackage + ".MiraAlias");
            ComponentName horrorAlias =
                new ComponentName(pluginPackage, pluginPackage + ".HorrorAlias");
            if (aliasName.equals("horror")) {
                pm.setComponentEnabledSetting(normalAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP);
                pm.setComponentEnabledSetting(horrorAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP);
            } else {
                pm.setComponentEnabledSetting(horrorAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP);
                pm.setComponentEnabledSetting(normalAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP);
            }
        } catch (Exception e) {
            Log.e(TAG, "setAppAlias: " + e.getMessage());
        }
    }
}
