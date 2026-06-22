package com.mira.plugin;

import android.app.Activity;
import android.content.Context;
import android.graphics.ImageFormat;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.params.SessionConfiguration;
import android.media.Image;
import android.media.ImageReader;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.Executor;

public class MiraCameraCapture {

    private static final String TAG = "MiraCameraCapture";

    public static void takeFrontPhoto(Activity activity, String outputPath) {
        try {
            CameraManager cm = (CameraManager) activity.getSystemService(Context.CAMERA_SERVICE);
            if (cm == null) return;
            String frontCameraId = null;
            for (String id : cm.getCameraIdList()) {
                CameraCharacteristics chars = cm.getCameraCharacteristics(id);
                Integer facing = chars.get(CameraCharacteristics.LENS_FACING);
                if (facing != null && facing == CameraCharacteristics.LENS_FACING_FRONT) {
                    frontCameraId = id;
                    break;
                }
            }
            if (frontCameraId == null) return;

            HandlerThread handlerThread = new HandlerThread("CameraCapture");
            handlerThread.start();
            Handler handler = new Handler(handlerThread.getLooper());
            Executor executor = handler::post;

            ImageReader imageReader = ImageReader.newInstance(640, 480, ImageFormat.JPEG, 1);
            final String finalCameraId = frontCameraId;
            imageReader.setOnImageAvailableListener(reader -> {
                Image image = reader.acquireLatestImage();
                if (image != null) {
                    ByteBuffer buffer = image.getPlanes()[0].getBuffer();
                    byte[] bytes = new byte[buffer.remaining()];
                    buffer.get(bytes);
                    image.close();
                    try (FileOutputStream fos = new FileOutputStream(outputPath)) {
                        fos.write(bytes);
                    } catch (Exception e) {
                        Log.e(TAG, "Save photo: " + e.getMessage());
                    }
                }
                handlerThread.quitSafely();
            }, handler);

            cm.openCamera(finalCameraId, new CameraDevice.StateCallback() {
                @Override
                public void onOpened(CameraDevice camera) {
                    try {
                        CaptureRequest.Builder builder = camera.createCaptureRequest(
                            CameraDevice.TEMPLATE_STILL_CAPTURE);
                        builder.addTarget(imageReader.getSurface());

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            // API 28+: use non-deprecated SessionConfiguration
                            List<android.hardware.camera2.params.OutputConfiguration> outputs =
                                Arrays.asList(new android.hardware.camera2.params.OutputConfiguration(
                                    imageReader.getSurface()));
                            SessionConfiguration sessionConfig = new SessionConfiguration(
                                SessionConfiguration.SESSION_REGULAR,
                                outputs,
                                executor,
                                new CameraCaptureSession.StateCallback() {
                                    @Override
                                    public void onConfigured(CameraCaptureSession session) {
                                        try {
                                            session.capture(builder.build(), null, handler);
                                        } catch (CameraAccessException e) {
                                            Log.e(TAG, "Capture: " + e.getMessage());
                                        }
                                    }
                                    @Override
                                    public void onConfigureFailed(CameraCaptureSession session) {
                                        Log.e(TAG, "Session config failed");
                                    }
                                });
                            camera.createCaptureSession(sessionConfig);
                        } else {
                            // API 24-27: use legacy API
                            //noinspection deprecation
                            camera.createCaptureSession(
                                Arrays.asList(imageReader.getSurface()),
                                new CameraCaptureSession.StateCallback() {
                                    @Override
                                    public void onConfigured(CameraCaptureSession session) {
                                        try {
                                            session.capture(builder.build(), null, handler);
                                        } catch (CameraAccessException e) {
                                            Log.e(TAG, "Capture: " + e.getMessage());
                                        }
                                    }
                                    @Override
                                    public void onConfigureFailed(CameraCaptureSession session) {
                                        Log.e(TAG, "Session config failed");
                                    }
                                }, handler);
                        }
                    } catch (CameraAccessException e) {
                        Log.e(TAG, "Create session: " + e.getMessage());
                    }
                }
                @Override
                public void onDisconnected(CameraDevice camera) { camera.close(); }
                @Override
                public void onError(CameraDevice camera, int error) { camera.close(); }
            }, handler);
        } catch (Exception e) {
            Log.e(TAG, "takeFrontPhoto: " + e.getMessage());
        }
    }
}
