# Firebase Authentication Setup for Snap2Done

This document provides step-by-step instructions for setting up Firebase Authentication in the Snap2Done app, with a focus on Apple Sign-In.

## 1. Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click on "Add project" and follow the prompts to create a new project named "snap2done".
3. Complete the project setup wizard.

## 2. Add iOS App to Firebase Project

1. In the Firebase console, select your project.
2. Click on the iOS icon ("+") to add an iOS app.
3. Enter your app's bundle ID: `com.niryph.snap2done`.
4. Download the `GoogleService-Info.plist` file.
5. Place this file in the `ios/Runner` directory of your Flutter project.

## 3. Configure Apple Sign-In

### Configure Firebase

1. In the Firebase console, go to "Authentication".
2. Click on "Sign-in method".
3. Enable "Apple" as a sign-in provider.
4. Add the following configuration:
   - Service ID: Your Apple Service ID (e.g., `com.snap2done`)
   - Apple Team ID: Your Apple Developer Team ID
   - Key ID: The ID of the key you generated in your Apple Developer account
   - Private Key: The contents of the `.p8` file you downloaded from your Apple Developer account

### Configure Apple Developer Account

1. Log in to your [Apple Developer account](https://developer.apple.com/).
2. Go to "Certificates, Identifiers & Profiles".
3. Select "Identifiers" and add a new App ID if you don't have one.
4. Enable "Sign In with Apple" capability for your App ID.
5. Create a new Service ID:
   - Identifier: A unique identifier (e.g., `com.snap2done`)
   - Enable "Sign In with Apple"
   - Configure primary app ID
   - Add domain and return URL: `https://snap2done.firebaseapp.com/__/auth/handler`
6. Create a new key:
   - Select "Keys" and add a new key
   - Enable "Sign In with Apple"
   - Register the key and download the `.p8` file (store this securely)
   - Note the Key ID

### Update iOS Project

1. Ensure the `Runner.entitlements` file has the `com.apple.developer.applesignin` capability.
2. Update the Info.plist with the necessary URL schemes for Firebase authentication.
3. Update the `GoogleService-Info.plist` with your Firebase configuration.

## 4. Testing

1. Run the app on an iOS device or simulator.
2. Attempt to sign in with Apple.
3. Verify that the authentication process completes successfully.
4. Check the Firebase Authentication console to confirm that the user was created.

## Troubleshooting

If you encounter issues with Apple Sign-In:

1. Verify that all configuration values in Firebase match those in your Apple Developer account.
2. Ensure that the bundle ID in Xcode matches the one registered in Firebase and Apple Developer.
3. Check that the `.p8` key file has been properly generated and its contents correctly added to Firebase.
4. Look for any errors in the Xcode console during the authentication process.
5. Verify that the app has the correct entitlements and capabilities enabled in Xcode.

## Additional Resources

- [Firebase Authentication Documentation](https://firebase.google.com/docs/auth)
- [Sign In with Apple Documentation](https://developer.apple.com/sign-in-with-apple/) 