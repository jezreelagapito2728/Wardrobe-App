# Closet Mate - Setup Guide

## 1. Direct APK Download (Without App Store)

### Step 1: Build the APK
```bash
flutter build apk --release
```

The APK will be generated at: `build/app/outputs/apk/release/app-release.apk`

### Step 2: Host the APK

Choose one of these hosting options:

#### Option A: GitHub Releases (Recommended - Free)
1. Go to your GitHub repository
2. Click "Releases" → "Create a new release"
3. Upload `app-release.apk` file
4. Get the download URL from the asset
5. Update the URL in `lib/screens/download_page.dart`:
   ```dart
   static const String APK_DOWNLOAD_URL = 'https://github.com/yourusername/closet_mate/releases/download/v1.0.0/app-release.apk';
   ```

#### Option B: Firebase Storage
1. Go to Firebase Console → Storage
2. Upload `app-release.apk`
3. Get the download URL
4. Update the URL in `lib/screens/download_page.dart`:
   ```dart
   static const String APK_DOWNLOAD_URL = 'https://firebasestorage.googleapis.com/v0/b/yourproject.appspot.com/o/app-release.apk?alt=media';
   ```

#### Option C: Your Web Server
1. Upload APK to your server
2. Update the URL in `lib/screens/download_page.dart`:
   ```dart
   static const String APK_DOWNLOAD_URL = 'https://yourdomain.com/downloads/closet_mate.apk';
   ```

### Step 3: Test the Download
- Build and run the app
- Go to Settings → Download App
- Scan the QR code or tap "Download APK Directly"
- The APK should start downloading

---

## 2. Background Removal for Images

### Option A: Using remove.bg API (Recommended - More Accurate)

**Free Tier: 50 API calls/month**

1. Go to https://www.remove.bg/api
2. Sign up for a free account
3. Copy your API key
4. Update `lib/services/bg_remover.dart`:
   ```dart
   static const String REMOVE_BG_API_KEY = 'YOUR_ACTUAL_API_KEY';
   ```
5. Update `pubspec.yaml` dependencies:
   ```yaml
   dependencies:
     http: ^1.1.0
   ```
6. Run: `flutter pub get`

**How it works:**
- When a user uploads an image, the app will send it to remove.bg API
- The API removes the background and returns a transparent PNG
- Falls back to local processing if API call fails or quota exceeded

### Option B: Local Processing (No Cost)
- If you don't set up remove.bg API, the app automatically uses local background removal
- Less accurate but works offline
- No API quota limits

---

## 3. Browse Page Transparency Fix

✅ **Already Done!**

The browse page cards now have:
- Transparent background (no grey placeholder)
- Clean minimal design
- Shadow effect for depth
- Only shows image content

---

## 4. Add Item Background Removal

When users add clothing items:
1. They select an image
2. The background is automatically removed using:
   - remove.bg API (if configured and quota available)
   - Local processing (fallback)
3. The image is stored with transparent background

---

## Quick Setup Checklist

- [ ] Build APK: `flutter build apk --release`
- [ ] Choose hosting option (GitHub/Firebase/Web server)
- [ ] Update APK URL in `download_page.dart`
- [ ] (Optional) Get remove.bg API key from https://www.remove.bg/api
- [ ] (Optional) Update REMOVE_BG_API_KEY in `bg_remover.dart`
- [ ] Run: `flutter pub get`
- [ ] Test the download page
- [ ] Test image upload with background removal

---

## Troubleshooting

### Remove.bg API Not Working
- Check API key is correct
- Verify monthly quota hasn't been exceeded (50 calls/month free)
- Check internet connection
- App will automatically fall back to local processing

### APK Download Not Working
- Verify URL is correct and accessible
- Check internet connection
- Ensure the APK file exists at the hosted location
- Test URL directly in browser

### Background Removal Not Working
- If using remove.bg: check API key and quota
- Try uploading a simpler image with clear background
- Local fallback should still work

---

## Additional Resources

- Remove.bg API Docs: https://www.remove.bg/api
- GitHub Releases: https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
- Firebase Storage: https://firebase.google.com/docs/storage
- Flutter url_launcher: https://pub.dev/packages/url_launcher
