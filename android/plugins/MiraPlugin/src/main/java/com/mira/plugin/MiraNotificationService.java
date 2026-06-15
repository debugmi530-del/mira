package com.mira.plugin;

import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import java.util.ArrayList;
import java.util.List;

public class MiraNotificationService extends NotificationListenerService {

    private static final String TAG = "MiraNotification";
    private static final int MAX_STORED = 50;
    private static final List<String> storedNotifications = new ArrayList<>();

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        try {
            String packageName = sbn.getPackageName();
            android.os.Bundle extras = sbn.getNotification().extras;
            String title = extras.getString(android.app.Notification.EXTRA_TITLE, "");
            CharSequence text = extras.getCharSequence(android.app.Notification.EXTRA_TEXT);
            String textStr = text != null ? text.toString() : "";
            String entry = packageName + "|||" + title + "|||" + textStr +
                "|||" + System.currentTimeMillis();
            synchronized (storedNotifications) {
                storedNotifications.add(0, entry);
                if (storedNotifications.size() > MAX_STORED) {
                    storedNotifications.remove(storedNotifications.size() - 1);
                }
            }
            Log.d(TAG, "Notification: " + title + " from " + packageName);
        } catch (Exception e) {
            Log.e(TAG, "onNotificationPosted: " + e.getMessage());
        }
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
    }

    public static List<String> getStoredNotifications() {
        synchronized (storedNotifications) {
            return new ArrayList<>(storedNotifications);
        }
    }
}
