package com.cola;

import android.content.Intent;
import android.net.VpnService;
import android.os.Binder;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.ParcelFileDescriptor;

import java.util.ArrayList;
import java.util.List;

import cola.Closer;
import cola.Cola_;
import cola.Protector;


public class ColaService extends VpnService implements Runnable {
    private Thread mThread;
    private Bundle mProfile;
    private Object mLock = new Object();
    private String mStatus = "disconnected";
    private ParcelFileDescriptor mInterface;
    private final IBinder mBinder = new LocalBinder();
    private final List<StatusListener> mListeners = new ArrayList<>();
    private Handler mHandler = new Handler();

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        //Log.i("xtun", "onStartCommand");
        if (intent != null) {
            if (intent.getAction().equals("connect"))
                start(intent.getExtras());
            else if (intent.getAction().equals("disconnect"))
                stop();
        }
        return START_NOT_STICKY;//service被kill后不重启
    }

    @Override
    public IBinder onBind(Intent intent) {
        //Log.i("xtun", "onBind");
        //return super.onBind(intent);
        return mBinder;
    }

    @Override
    public void onDestroy() {
        //Log.i("xtun", "onDestroy");
        stop();
    }

    private synchronized void start(Bundle bundle) {
        if (bundle != null) {
            //Log.i("xtun", "start");
            stop();
            mProfile = bundle;
            //mLoop = true;
            mThread = new Thread(this);
            mThread.start();
        }
    }

    private synchronized void stop() {
        if (mThread != null) {
            //Log.i("xtun", "stop");
            synchronized (mLock) {
                mLock.notify();
            }
            try {
                mThread.join();
            } catch (Exception e) {
            }
        }
    }

    @Override
    public void run() {
        setStatus("connecting");
        String name = mProfile.getString("name");
        String config = mProfile.getString("config");
        try {
            Protector p = new Protector() {
                @Override
                public void control(long fd) {
                    protect((int) fd);
                }
            };
            Cola_ cola = new Cola_(p, config);
            setStatus("connected");
            mInterface = establish(name, cola);
            cola.createTun(mInterface.getFd(), "tun0");
            Closer closer = new Closer() {
                @Override
                public void onClose() {
                    synchronized (mLock) {
                        mLock.notify();
                    }
                }
            };
            cola.start(closer);
            synchronized (mLock) {
                mLock.wait();
            }
            setStatus("disconnecting");
            cola.stop();
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            if (mInterface != null) {
                try {
                    mInterface.close();
                } catch (Exception e) {
                }
                mInterface = null;
            }
        }
        setStatus("disconnected");
        mThread = null;
    }

    private ParcelFileDescriptor establish(String name, Cola_ cola) throws Exception {

        Builder builder = new Builder();
        builder.setSession(name);
        builder.setMtu((int) cola.mtu());

        String[] arr = cola.cidr().split("/");
        builder.addAddress(cola.clientIP(), Integer.valueOf(arr[1]));
        builder.addDnsServer(arr[0]);

        String routes = "";
        int mode = (int) cola.mode();
        if (mode > 0) {
            routes = cola.generateCIDRs("0/16", true);//"0.0.0.0/0";
            if (cola.smart() == 1) {
                if (mode == 2) {
                    routes = cola.generateCIDRs("0,1/16", true);
                } else if (mode == 3) {
                    routes = cola.generateCIDRs("1/16", false);
                }
            }
            for (String cidr : routes.split("\n")) {
                String[] arr1 = cidr.split("/");
                builder.addRoute(arr1[0], Integer.valueOf(arr1[1]));
            }
        }
        builder.addRoute("10.6.0.0",16);//tun2socks有效
        return builder.establish();
    }

    public class LocalBinder extends Binder {
        public ColaService getService() {
            return ColaService.this;
        }
    }

    public interface StatusListener {
        public void statusChanged(String status);
    }

    public String getStatus() {
        return mStatus;
    }

    public void registerListener(StatusListener listener) {
        mListeners.add(listener);
    }

    public void unregisterListener(StatusListener listener) {
        mListeners.remove(listener);
    }

    private void notifyListeners(final String status) {
        mHandler.post(new Runnable() {
            @Override
            public void run() {
                for (StatusListener listener : mListeners) {
                    listener.statusChanged(status);
                }
            }
        });
    }

    public void setStatus(String status) {
        if (!status.equals(mStatus)) {
            mStatus = status;
            notifyListeners(mStatus);
        }
    }
}
