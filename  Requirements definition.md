# 要件定義書: Widget Message Sync for iOS (MVP) - Supabase版

## 1. プロジェクト概要
Flutterアプリからテキストを送信し、ペアリングした相手（知人）のiOSホーム画面ウィジェットにその内容を即座に反映させる。

## 2. コア機能 (MVP)
### 2.1 匿名認証 (Anonymous Auth)
* Supabase Auth を使用。匿名認証（Anonymous Sign-ins）を有効にし、UIDを取得する。

### 2.2 簡易ペアリング (Simple Pairing)
* 自分のUIDを表示。
* 相手のUIDを入力・保存し、送信先ターゲットとして設定する。

### 2.3 メッセージ同期 (Message Syncing)
* 送信ボタン押下時、Supabaseの `messages` テーブル内の、相手のUIDに対応するレコードを更新（Upsert）する。

### 2.4 iOSウィジェット表示 (iOS Widget Display)
* `home_widget` パッケージを使用。
* `App Groups` を経由して、SwiftUIウィジェットへデータを共有する。

## 3. 技術スタック
* **Framework:** Flutter
* **Backend:** Supabase (Auth, Database/PostgreSQL, Realtime)
* **iOS Native:** SwiftUI (WidgetKit), App Groups
* **Key Package:** `supabase_flutter`, `home_widget`

## 4. データベース設計 (Supabase Table)
### messages テーブル
* `id`: uuid (Primary Key, 相手のUIDと一致させる)
* `content`: text
* `updated_at`: timestamp with time zone (default: now())

## 5. 実装ステップ (AIへの指示順)

### Step 1: Supabase Setup & Pairing UI
* Supabaseプロジェクトを作成し、匿名認証を有効にする。
* Flutterで自分のUIDを表示し、相手のUIDを `shared_preferences` に保存する画面を作成。

### Step 2: Message Update Logic
* 入力したテキストを、相手のUIDをキーにして `messages` テーブルへUpsert（更新）する関数を実装。
* 更新成功時に `home_widget` を叩き、自分のウィジェットも更新されるかテストする。

### Step 3: iOS Widget Implementation
* `App Group ID` を設定し、SwiftUI側で共有データを読み取って表示する。