diff --git a/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/BitmapSizeDecoder.java b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/BitmapSizeDecoder.java
new file mode 100644
index 0000000..5614e4f
--- /dev/null
+++ b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/BitmapSizeDecoder.java
@@ -0,0 +1,39 @@
+package com.dylanvann.fastimage;
+
+import android.graphics.BitmapFactory;
+import android.media.ExifInterface;
+
+import androidx.annotation.NonNull;
+import androidx.annotation.Nullable;
+
+import com.bumptech.glide.load.Options;
+import com.bumptech.glide.load.ResourceDecoder;
+import com.bumptech.glide.load.engine.Resource;
+import com.bumptech.glide.load.resource.SimpleResource;
+
+import java.io.File;
+import java.io.IOException;
+
+public class BitmapSizeDecoder implements ResourceDecoder<File, BitmapFactory.Options> {
+
+    @Override
+    public boolean handles(@NonNull File source, @NonNull Options options) throws IOException {
+        return true;
+    }
+
+    @Nullable
+    @Override
+    public Resource<BitmapFactory.Options> decode(@NonNull File source, int width, int height, @NonNull Options options) throws IOException {
+        BitmapFactory.Options bitmapOptions = new BitmapFactory.Options();
+        bitmapOptions.inJustDecodeBounds = true;
+        BitmapFactory.decodeFile(source.getAbsolutePath(), bitmapOptions);
+        int orientation = Integer.parseInt(new ExifInterface(source.getAbsolutePath()).getAttribute(ExifInterface.TAG_ORIENTATION));
+        if (orientation == ExifInterface.ORIENTATION_ROTATE_90 || orientation == ExifInterface.ORIENTATION_ROTATE_270) {
+            int outHeight = bitmapOptions.outHeight;
+            int outWidth = bitmapOptions.outWidth;
+            bitmapOptions.outHeight = outWidth;
+            bitmapOptions.outWidth = outHeight;
+        }
+        return new SimpleResource(bitmapOptions);
+    }
+}
\ No newline at end of file
diff --git a/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/BitmapSizeTranscoder.java b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/BitmapSizeTranscoder.java
new file mode 100644
index 0000000..7d208d1
--- /dev/null
+++ b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/BitmapSizeTranscoder.java
@@ -0,0 +1,23 @@
+package com.dylanvann.fastimage;
+
+import android.graphics.BitmapFactory;
+
+import androidx.annotation.NonNull;
+import androidx.annotation.Nullable;
+
+import com.bumptech.glide.load.Options;
+import com.bumptech.glide.load.engine.Resource;
+import com.bumptech.glide.load.resource.SimpleResource;
+import com.bumptech.glide.load.resource.transcode.ResourceTranscoder;
+
+public class BitmapSizeTranscoder implements ResourceTranscoder<BitmapFactory.Options, Size> {
+    @Nullable
+    @Override
+    public Resource<Size> transcode(@NonNull Resource<BitmapFactory.Options> toTranscode, @NonNull Options options) {
+        BitmapFactory.Options bitmap = toTranscode.get();
+        Size size = new Size();
+        size.width = bitmap.outWidth;
+        size.height = bitmap.outHeight;
+        return new SimpleResource(size);
+    }
+}
\ No newline at end of file
diff --git a/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageOkHttpProgressGlideModule.java b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageOkHttpProgressGlideModule.java
index 811292a..dcfb413 100644
--- a/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageOkHttpProgressGlideModule.java
+++ b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageOkHttpProgressGlideModule.java
@@ -2,6 +2,7 @@ package com.dylanvann.fastimage;
 
 import android.content.Context;
 import androidx.annotation.NonNull;
+import android.graphics.BitmapFactory;
 
 import com.bumptech.glide.Glide;
 import com.bumptech.glide.Registry;
@@ -11,6 +12,7 @@ import com.bumptech.glide.load.model.GlideUrl;
 import com.bumptech.glide.module.LibraryGlideModule;
 import com.facebook.react.modules.network.OkHttpClientProvider;
 
+import java.io.File;
 import java.io.IOException;
 import java.io.InputStream;
 import java.util.HashMap;
@@ -47,6 +49,9 @@ public class FastImageOkHttpProgressGlideModule extends LibraryGlideModule {
                 .build();
         OkHttpUrlLoader.Factory factory = new OkHttpUrlLoader.Factory(client);
         registry.replace(GlideUrl.class, InputStream.class, factory);
+        // Decoder + Transcoder pair for InputStream -> Size
+        registry.prepend(File.class, BitmapFactory.Options.class, new BitmapSizeDecoder());
+        registry.register(BitmapFactory.Options.class, Size.class, new BitmapSizeTranscoder());
     }
 
     private static Interceptor createInterceptor(final ResponseProgressListener listener) {
diff --git a/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageRequestListener.java b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageRequestListener.java
index dbeb813..bf8f21c 100644
--- a/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageRequestListener.java
+++ b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageRequestListener.java
@@ -22,13 +22,6 @@ public class FastImageRequestListener implements RequestListener<Drawable> {
         this.key = key;
     }
 
-    private static WritableMap mapFromResource(Drawable resource) {
-        WritableMap resourceData = new WritableNativeMap();
-        resourceData.putInt("width", resource.getIntrinsicWidth());
-        resourceData.putInt("height", resource.getIntrinsicHeight());
-        return resourceData;
-    }
-
     @Override
     public boolean onLoadFailed(@androidx.annotation.Nullable GlideException e, Object model, Target<Drawable> target, boolean isFirstResource) {
         FastImageOkHttpProgressGlideModule.forget(key);
@@ -53,7 +46,6 @@ public class FastImageRequestListener implements RequestListener<Drawable> {
         ThemedReactContext context = (ThemedReactContext) view.getContext();
         RCTEventEmitter eventEmitter = context.getJSModule(RCTEventEmitter.class);
         int viewId = view.getId();
-        eventEmitter.receiveEvent(viewId, REACT_ON_LOAD_EVENT, mapFromResource(resource));
         eventEmitter.receiveEvent(viewId, REACT_ON_LOAD_END_EVENT, new WritableNativeMap());
         return false;
     }
diff --git a/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageViewWithUrl.java b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageViewWithUrl.java
index 34fcf89..8f6e741 100644
--- a/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageViewWithUrl.java
+++ b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/FastImageViewWithUrl.java
@@ -2,6 +2,7 @@ package com.dylanvann.fastimage;
 
 import static com.dylanvann.fastimage.FastImageRequestListener.REACT_ON_ERROR_EVENT;
 
+import androidx.annotation.NonNull;
 import android.annotation.SuppressLint;
 import android.content.Context;
 import android.graphics.drawable.Drawable;
@@ -9,16 +10,26 @@ import android.graphics.drawable.Drawable;
 import androidx.annotation.Nullable;
 import androidx.appcompat.widget.AppCompatImageView;
 
+import com.bumptech.glide.Glide;
 import com.bumptech.glide.RequestBuilder;
 import com.bumptech.glide.RequestManager;
+import com.bumptech.glide.load.DataSource;
+import com.bumptech.glide.load.engine.DiskCacheStrategy;
+import com.bumptech.glide.load.engine.GlideException;
 import com.bumptech.glide.load.model.GlideUrl;
 import com.bumptech.glide.request.Request;
+import com.bumptech.glide.request.RequestListener;
+import com.bumptech.glide.request.RequestOptions;
+import com.bumptech.glide.request.target.SimpleTarget;
+import com.bumptech.glide.request.target.Target;
+import com.bumptech.glide.request.transition.Transition;
 import com.facebook.react.bridge.ReadableMap;
 import com.facebook.react.bridge.WritableMap;
 import com.facebook.react.bridge.WritableNativeMap;
 import com.facebook.react.uimanager.ThemedReactContext;
 import com.facebook.react.uimanager.events.RCTEventEmitter;
 
+import java.io.File;
 import java.util.ArrayList;
 import java.util.Collections;
 import java.util.List;
@@ -124,9 +135,34 @@ class FastImageViewWithUrl extends AppCompatImageView {
             RCTEventEmitter eventEmitter = context.getJSModule(RCTEventEmitter.class);
             int viewId = this.getId();
 
-            eventEmitter.receiveEvent(viewId,
-                    FastImageViewManager.REACT_ON_LOAD_START_EVENT,
-                    new WritableNativeMap());
+            // Request the URL from cache to see if it exists there and if so pass the cache
+            // path as an argument in the onLoadStart event
+            requestManager
+                    .asFile()
+                    .load(glideUrl)
+                    .onlyRetrieveFromCache(true)
+                    .listener(new RequestListener<File>() {
+                        @Override
+                        public boolean onLoadFailed(@Nullable GlideException e, Object model, Target<File> target, boolean isFirstResource) {
+                            WritableNativeMap result = new WritableNativeMap();
+                            result.putNull("cachePath");
+                            eventEmitter.receiveEvent(viewId,
+                                    FastImageViewManager.REACT_ON_LOAD_START_EVENT,
+                                    result);
+                            return false;
+                        }
+
+                        @Override
+                        public boolean onResourceReady(File resource, Object model, Target<File> target, DataSource dataSource, boolean isFirstResource) {
+                            WritableNativeMap result = new WritableNativeMap();
+                            result.putString("cachePath", resource.getAbsolutePath());
+                            eventEmitter.receiveEvent(viewId,
+                                    FastImageViewManager.REACT_ON_LOAD_START_EVENT,
+                                    result);
+                            return false;
+                        }
+                    })
+                    .submit();
         }
 
         if (requestManager != null) {
@@ -148,6 +184,28 @@ class FastImageViewWithUrl extends AppCompatImageView {
                 builder.listener(new FastImageRequestListener(key));
 
             builder.into(this);
+
+            // Used specifically to handle the `onLoad` event for the image
+            RCTEventEmitter eventEmitter = context.getJSModule(RCTEventEmitter.class);
+            int viewId = this.getId();
+            requestManager
+                .as(Size.class)
+                .apply(new RequestOptions()
+                        .skipMemoryCache(true)
+                        .diskCacheStrategy(DiskCacheStrategy.DATA))
+                .load(imageSource == null ? null : imageSource.getUri())
+                .into(new SimpleTarget<Size>() {
+                    @Override
+                    public void onResourceReady(@NonNull Size resource, @Nullable Transition<? super Size> transition) {
+                        WritableMap resourceData = new WritableNativeMap();
+                        resourceData.putInt("width", resource.width);
+                        resourceData.putInt("height", resource.height);
+                        eventEmitter.receiveEvent(viewId,
+                            "onFastImageLoad",
+                            resourceData
+                        );
+                    }
+                });
         }
     }
 
diff --git a/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/Size.java b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/Size.java
new file mode 100644
index 0000000..2fe8a47
--- /dev/null
+++ b/node_modules/react-native-fast-image/android/src/main/java/com/dylanvann/fastimage/Size.java
@@ -0,0 +1,6 @@
+package com.dylanvann.fastimage;
+
+public class Size {
+    int width;
+    int height;
+}
\ No newline at end of file
diff --git a/node_modules/react-native-fast-image/dist/index.d.ts b/node_modules/react-native-fast-image/dist/index.d.ts
index 5abb7c9..a2672c6 100644
--- a/node_modules/react-native-fast-image/dist/index.d.ts
+++ b/node_modules/react-native-fast-image/dist/index.d.ts
@@ -27,6 +27,11 @@ export declare type Source = {
     priority?: Priority;
     cache?: Cache;
 };
+export interface OnLoadStartEvent {
+    nativeEvent: {
+        cachePath: string | null;
+    };
+}
 export interface OnLoadEvent {
     nativeEvent: {
         width: number;
@@ -57,7 +62,7 @@ export interface FastImageProps extends AccessibilityProps, ViewProps {
     defaultSource?: ImageRequireSource;
     resizeMode?: ResizeMode;
     fallback?: boolean;
-    onLoadStart?(): void;
+    onLoadStart?(event: OnLoadStartEvent): void;
     onProgress?(event: OnProgressEvent): void;
     onLoad?(event: OnLoadEvent): void;
     onError?(): void;
diff --git a/node_modules/react-native-fast-image/ios/FastImage/FFFastImageView.m b/node_modules/react-native-fast-image/ios/FastImage/FFFastImageView.m
index f710081..391ef92 100644
--- a/node_modules/react-native-fast-image/ios/FastImage/FFFastImageView.m
+++ b/node_modules/react-native-fast-image/ios/FastImage/FFFastImageView.m
@@ -54,7 +54,6 @@ - (void) setOnFastImageError: (RCTDirectEventBlock)onFastImageError {
 - (void) setOnFastImageLoadStart: (RCTDirectEventBlock)onFastImageLoadStart {
     if (_source && !self.hasSentOnLoadStart) {
         _onFastImageLoadStart = onFastImageLoadStart;
-        onFastImageLoadStart(@{});
         self.hasSentOnLoadStart = YES;
     } else {
         _onFastImageLoadStart = onFastImageLoadStart;
@@ -188,7 +187,18 @@ - (void) reloadImage {
         }
 
         if (self.onFastImageLoadStart) {
-            self.onFastImageLoadStart(@{});
+          NSString* cachePath = [[SDImageCache sharedImageCache] cachePathForKey:url];
+          BOOL isCached = [[SDImageCache sharedImageCache] diskImageDataExistsWithKey:url];
+          if (isCached) {
+            self.onFastImageLoadStart(@{
+              @"cachePath": cachePath
+            });
+          }
+          else {
+            self.onFastImageLoadStart(@{
+              @"cachePath": [NSNull null]
+            });
+          }
             self.hasSentOnLoadStart = YES;
         } else {
             self.hasSentOnLoadStart = NO;
