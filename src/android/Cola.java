package com.cola;

import android.app.Activity;
import android.app.Service;
import android.content.ComponentName;
import android.content.Intent;
import android.content.ServiceConnection;
import android.net.VpnService;
import android.os.Bundle;
import android.os.IBinder;
import android.provider.Settings;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;

public class Cola extends CordovaPlugin implements ColaService.StatusListener {
    private CallbackContext onStatusCallbackContext;
    private Bundle mProfileInfo;
    private ColaService mService;
    private final ServiceConnection mServiceConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            mService = ((ColaService.LocalBinder) service).getService();
            mService.registerListener(Cola.this);
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            mService.unregisterListener(Cola.this);
            mService = null;
        }
    };

    @Override
    public void statusChanged(String status) {
        if (onStatusCallbackContext != null) {
            PluginResult result = new PluginResult(PluginResult.Status.OK, status);
            result.setKeepCallback(true);
            onStatusCallbackContext.sendPluginResult(result);
        }
    }

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        this.onStatusCallbackContext = null;
        cordova.getActivity().bindService(new Intent(cordova.getActivity(), ColaService.class), mServiceConnection, Service.BIND_AUTO_CREATE);//绑定服务
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (mService != null)//销毁服务
        {
            cordova.getActivity().unbindService(mServiceConnection);
        }
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        switch (action){
            case "uuid":
                String uuid = Settings.Secure.getString(this.cordova.getActivity().getContentResolver(), android.provider.Settings.Secure.ANDROID_ID);
                callbackContext.success(uuid);
                return true;
            case "platform":
                callbackContext.success("android");
                return true;
            case "connect":
                try {
                    mProfileInfo = new Bundle();
                    mProfileInfo.putString("name", args.getString(0));
                    mProfileInfo.putString("config", args.getString(1));
                    Intent intent = VpnService.prepare(cordova.getActivity());
                    if (intent != null) {
                        cordova.setActivityResultCallback(this);
                        cordova.getActivity().startActivityForResult(intent, 0);//用户权限请求确认
                    } else {
                        onActivityResult(0, Activity.RESULT_OK, null);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
                callbackContext.success();
                return true;
            case "disconnect":
                Intent intent = new Intent(cordova.getActivity(), ColaService.class);
                intent.setAction("disconnect");
                cordova.getActivity().startService(intent);
                callbackContext.success();
                return true;
            case "getStatus":
                String status = mService == null ? "disconnected" : mService.getStatus();
                callbackContext.success(status);
                return true;
            case "onStatus":
                this.onStatusCallbackContext = callbackContext;
                PluginResult pluginResult = new PluginResult(PluginResult.Status.NO_RESULT);
                pluginResult.setKeepCallback(true);
                callbackContext.sendPluginResult(pluginResult);
                return true;
        }
        return false;
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (resultCode == Activity.RESULT_OK && mProfileInfo != null) {
            Intent intent = new Intent(cordova.getActivity(), ColaService.class);
            intent.setAction("connect");
            intent.putExtras(mProfileInfo);
            cordova.getActivity().startService(intent);
        }
    }
}
