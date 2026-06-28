package com.mira.plugin;

import android.app.Service;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.TextView;

public class MiraOverlayService extends Service {

    private WindowManager windowManager;
    private FrameLayout overlayView;

    @Override
    public IBinder onBind(Intent intent) { return null; }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String message = (intent != null) ? intent.getStringExtra("message") : null;
        if (message == null || message.isEmpty()) message = "Я здесь.";
        showOverlay(message);
        return START_NOT_STICKY;
    }

    private void showOverlay(String message) {
        if (overlayView != null) return;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            stopSelf();
            return;
        }

        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);

        // Корневой контейнер — тёмный полупрозрачный экран
        overlayView = new FrameLayout(this);
        overlayView.setBackgroundColor(Color.argb(230, 8, 12, 18));

        // Текст Миры
        TextView tv = new TextView(this);
        tv.setText(message);
        tv.setTextColor(Color.argb(255, 80, 190, 130));
        tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, 26);
        tv.setGravity(Gravity.CENTER);
        tv.setTypeface(Typeface.DEFAULT_BOLD);
        tv.setLineSpacing(0f, 1.4f);
        tv.setPadding(64, 64, 64, 64);

        FrameLayout.LayoutParams tvParams = new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER
        );
        overlayView.addView(tv, tvParams);

        // Нажать — убрать оверлей
        overlayView.setOnClickListener(v -> stopSelf());

        // Параметры окна
        int type = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            : WindowManager.LayoutParams.TYPE_PHONE;

        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        );
        params.gravity = Gravity.TOP | Gravity.START;

        windowManager.addView(overlayView, params);
    }

    @Override
    public void onDestroy() {
        if (overlayView != null && windowManager != null) {
            try { windowManager.removeView(overlayView); } catch (Exception ignored) {}
            overlayView = null;
        }
        super.onDestroy();
    }
}
