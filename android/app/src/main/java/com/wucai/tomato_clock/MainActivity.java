package com.wucai.tomato_clock;

import android.app.PictureInPictureParams;
import android.os.Build;
import android.util.Rational;
import android.view.WindowManager;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "tomato_clock/platform";
    private boolean pipEnabled = false;
    private String pipTitle = "";
    private String pipSubtitle = "";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "setKeepScreenOn":
                    setKeepScreenOn(Boolean.TRUE.equals(call.argument("enabled")));
                    result.success(null);
                    break;
                case "setPipState":
                    pipEnabled = Boolean.TRUE.equals(call.argument("enabled"));
                    pipTitle = stringArgument(call.argument("title"));
                    pipSubtitle = stringArgument(call.argument("subtitle"));
                    updatePictureInPictureParams();
                    result.success(null);
                    break;
                case "enterPictureInPicture":
                    result.success(enterPictureInPictureIfPossible());
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    @Override
    public void onUserLeaveHint() {
        if (pipEnabled) {
            enterPictureInPictureIfPossible();
        }
        super.onUserLeaveHint();
    }

    private void setKeepScreenOn(boolean enabled) {
        if (enabled) {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        } else {
            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
    }

    private void updatePictureInPictureParams() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            setPictureInPictureParams(buildPictureInPictureParams());
        }
    }

    private boolean enterPictureInPictureIfPossible() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || !pipEnabled) {
            return false;
        }
        return enterPictureInPictureMode(buildPictureInPictureParams());
    }

    private PictureInPictureParams buildPictureInPictureParams() {
        PictureInPictureParams.Builder builder = new PictureInPictureParams.Builder()
                .setAspectRatio(new Rational(1, 1));
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder
                    .setTitle(pipTitle)
                    .setSubtitle(pipSubtitle)
                    .setAutoEnterEnabled(pipEnabled);
        }
        return builder.build();
    }

    private String stringArgument(Object value) {
        return value == null ? "" : value.toString();
    }
}
