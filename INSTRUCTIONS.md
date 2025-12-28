# Setup Instructions for Widget Message Sync App

This project is a mock implementation of the iOS Widget Message Sync app using Flutter and Supabase.

## 1. Supabase Setup

1.  Go to [Supabase](https://supabase.com/) and create a new project.
2.  **Authentication**:
    *   Go to `Authentication` -> `Providers`.
    *   Enable **Anonymous Sign-ins**.
3.  **Database**:
    *   Go to `Table Editor` -> `New Table`.
    *   Name: `messages`
    *   Columns:
        *   `id`: uuid (Primary Key) - *Note: This will store the Target User's UID*
        *   `content`: text
        *   `updated_at`: timestamp (default: `now()`)
    *   **Policies (RLS)**:
        *   Enable RLS.
        *   Add policy for INSERT/UPDATE: Allow anyone (anon) to insert/update (for MVP simplicity).
        *   Add policy for SELECT: Allow anyone to read.
4.  **Get Keys**:
    *   Go to `Project Settings` -> `API`.
    *   Copy `Project URL` and `anon` public key.
5.  **Update Code**:
    *   Open `lib/main.dart`.
    *   Replace `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` with your actual values.

## 2. iOS Widget Setup (Xcode)

Since this involves native iOS features, you need to configure Xcode manually.

1.  Open the iOS project in Xcode:
    ```bash
    open ios/Runner.xcworkspace
    ```
2.  **Add App Groups**:
    *   Select the `Runner` project in the left navigator.
    *   Select the `Runner` target.
    *   Go to `Signing & Capabilities`.
    *   Click `+ Capability` and add **App Groups**.
    *   Click `+` in the App Groups section and create a new group: `group.com.example.widget_app` (or your own unique ID).
    *   *Note: If you change the ID, update `appGroupId` in `lib/main.dart`.*

3.  **Create Widget Extension**:
    *   In Xcode, go to `File` -> `New` -> `Target...`.
    *   Select **Widget Extension**.
    *   Product Name: `MessageWidget`.
    *   Uncheck "Include Live Activity" and "Include Configuration App Intent" (keep it simple).
    *   Click Finish.
    *   (If asked to activate scheme, say Cancel or Activate, doesn't matter much for now).

4.  **Configure Widget Extension**:
    *   Select the new `MessageWidget` target.
    *   Go to `Signing & Capabilities`.
    *   Add **App Groups**.
    *   Check the **same** App Group ID (`group.com.example.widget_app`).

5.  **Implement Widget Code**:
    *   Find the file `MessageWidget/MessageWidget.swift` in Xcode.
    *   Replace its entire content with the code provided in `ios/MessageWidget.swift` (in this project root).

## 3. Run the App

1.  Connect your iOS device or start a Simulator.
2.  Run the app:
    ```bash
    flutter run
    ```

## Usage

1.  **Device A (Sender)**:
    *   Open the app.
    *   Copy "My User ID".
    *   (In a real scenario, you would share this ID with Device B).
2.  **Device B (Receiver)**:
    *   Open the app.
    *   Enter Device A's ID into "Target User ID" and save.
    *   (Actually, for the MVP logic: The Sender needs the Receiver's ID).
    *   **Correct Flow**:
        *   **Receiver (Device B)**: Tells Sender their ID.
        *   **Sender (Device A)**: Enters Device B's ID as Target.
        *   **Sender**: Types message and clicks Send.
        *   **Receiver**: The Widget on Device B's home screen should update (requires background fetch or timeline reload logic, currently the mock updates the *local* widget for demonstration).

*Note: The current mock code updates the LOCAL widget when you click send, to demonstrate the `home_widget` functionality immediately. In a real production app, the Receiver's app needs to listen to Supabase Realtime changes or use Background Tasks to fetch the new message and update the widget.*
