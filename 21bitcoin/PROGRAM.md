# 21bitcoin Bug Bounty — PROGRAM（自社プログラム）

- **URL**: https://21bitcoin.app/en/bug-bounty
- **運営**: **FIOR Digital GmbH**（オーストリア FMA 認可の MiCAR 暗号資産サービスプロバイダー）
- **サービス**: 21bitcoin（Bitcoin 購入・積立・指値・利息・ウォレット・税務）
- **プラットフォーム**: **自社プログラム**（HackerOne/Immunefi/Bugcrowd を介さない）
- **報告先**:
  - Web フォーム（ページ下部の "Fill out the form below to report an error"）
  - `security@fior.digital`（追加情報・関連脆弱性）
- **記録日**: 2026-11-12

---

## 1. 報酬の資格（**3条件すべて**を満たす必要）

> "We will consider bounty rewards for disclosures that meet **all** the following criteria:"

1. **PoC（proof of concept）を含む** — 悪用手順を実証すること
2. **ユーザーデータの機密性・完全性・可用性に直接影響する**
3. **Section 2 の In-Scope 資産に該当する**

---

## 2. 報酬の支払い

- **新規の true positive のみ**（既知・false positive は対象外）
- **EUR のみ、SEPA 銀行口座へ**
- **EUR 建ての請求書（invoice）が必要**
- 賞与決定から **1週間以内**に支払い

---

## 3. Scope & テストルール

### In Scope
> "Testing is limited to the services operated by 21bitcoin, **including the mobile application
> and websites**. We **especially encourage you to test our mobile app since it is our core product**."

| 対象 | 備考 |
|---|---|
| **モバイルアプリ** | **中核製品。特に推奨** |
| **Web サイト** | 21bitcoin が運営するもの |
| **API エンドポイント** | 報告要件で「API エンドポイント」に言及 |

**→ 明示的なドメイン列挙なし。「21bitcoin が運営するサービス」全体。**

### アカウント
> "Only use accounts that belong to you personally for testing purposes."
> "Other users must not be harmed or affected by your tests."

**→ 自分のアカウントのみ。他ユーザーに影響を与えない。**

### 禁止テスト手法（**非網羅的リスト**）
| 禁止 |
|---|
| **ブルートフォース攻撃** |
| **クリックジャッキング / UI redressing** |
| **フィッシング / ソーシャルエンジニアリング** |
| **DoS / リソース枯渇** |
| **明示的な許可なき自動脆弱性スキャン** |
| 物理的な侵入・インフラ改ざん |

---

## 4. 報酬対象外

| 除外 |
|---|
| **一般的なベストプラクティスの指摘**（セキュリティヘッダ欠如・古いライブラリ等） |
| **Google の「non-qualifying reports」リストに該当するもの** |
| **自動ツールのみで発見し、手動検証のないもの** |

**→ "Google's list of non-qualifying reports" が適用される**（一般的な低品質報告の除外リスト）。

---

## 5. Responsible Disclosure

### 5.1 Safe Harbor
> "We grant you permission to test in-scope assets in good faith. No legal action will be taken
> against you for legitimate vulnerability research conducted according to these rules."

### 5.2 報告要件
- **明確で再現可能な手順**、スクリプト・ペイロードを含める
- **画面録画（.mp4）または説明文**で記録
- **CVSSv3 の深刻度を付与**
- **環境を明記**（production / staging / mobile app / API endpoints）

### 5.3 開示タイムライン
- 受領確認: **72時間以内**
- 重大な問題の修正: 検証から **30日以内**
- 公開開示: **60日後**まで待つ（複雑な場合は延長可）

### 5.4 コミュニケーション
- 専用チャネル（提出フォーム）
- 追加情報・関連脆弱性は `security@fior.digital`

### 5.5 データ保護
> "Do not exfiltrate real user data. If you inadvertently access sensitive information, stop testing
> and report it immediately. Any PII encountered must be treated confidentially and deleted."

---

## 前案件との比較

| 項目 | ListaDAO（前回） | **21bitcoin** |
|---|---|---|
| 形式 | BNB Chain 経由（第三者） | **自社プログラム** |
| 報酬 | P1 $20,001–100,000 | **金額非公開**（ケースバイケース） |
| 支払い | BNB（暗号資産） | **EUR・SEPA 銀行振込・請求書必要** |
| 対象 | スマートコントラクト 90 アドレス | **モバイルアプリ + Web + API** |
| 重点 | DeFi ロジック | **モバイルアプリが中核** |
| アカウント | 不要（オンチェーン） | **自分のアカウント必須** |

---

## 調査方針

### 特徴
1. **モバイルアプリが中核製品**（明示的に推奨）
2. **PoC が必須**（3条件のうち1つ）
3. **ユーザーデータへの直接影響**が必須
4. ブルートフォース・自動スキャン・DoS・クリックジャッキングは禁止
5. **Google の non-qualifying reports リスト**が適用

### 優先順位
| 優先 | 対象 | 理由 |
|---|---|---|
| **1** | **API の認可 / IDOR** | 「ユーザーデータへの直接影響」に合致。PoC も作りやすい |
| **2** | **認証フロー**（ログイン・2FA・セッション） | 同上 |
| **3** | **モバイルアプリ**（APK/IPA の静的解析） | 中核製品。ただし実機テストが理想 |
| **4** | Web サイトの XSS / インジェクション | PoC 容易 |
| 除外 | ヘッダ欠如・古いライブラリ・自動スキャン結果 | 明示的に報酬対象外 |

### 制約
- **自分のアカウントのみ**（登録が必要な可能性）
- **他ユーザーに影響を与えない**
- **ブルートフォース・自動スキャン禁止**
- **PII を取得したら即停止・削除**

---

## 基本構造の把握（2026-11-12 23:30-23:50）

### ホスト構成（crt.sh + DNS、パッシブのみ）

| ホスト | 状態 | 技術 / 役割 |
|---|---|---|
| `21bitcoin.app` | 198.202.211.1（**Webflow CDN**） | **マーケティングサイト**（Webflow、jQuery 3.5.1、GSAP） |
| **`account.21bitcoin.app`** | 200 / 551b、`server: cloudflare` | **★ 実アプリの SPA シェル**（body 空、JS で描画） |
| `data.21bitcoin.app` | **接続不可** | 内部データ用？ |
| `feedback.21bitcoin.app` | **接続不可** | — |
| `forms.21bitcoin.app` | **404**（186KB） | — |
| `de.21bitcoin.app` / `en.21bitcoin.app` | （未確認） | 言語別サイト |
| `email.*` / `email.mail.*` / `email.news.*` | （未確認） | メール基盤 |
| `info.` / `media.` / `presentation.` / `www.` | （未確認） | — |
| `api.21bitcoin.app` | **NXDOMAIN** | 存在しない |
| `fior.digital` | 35.205.106.218 | 親会社 |

### ★ アプリ情報
| 項目 | 値 |
|---|---|
| Android パッケージ | **`fior.digital21app`** |
| iOS App ID | **`1579302952`** |
| Google Play | `play.google.com/store/apps/details?id=fior.digital21app` |
| App Store | `apps.apple.com/at/app/21bitcoin-buy-sell-bitcoin/id1579302952` |

### ★ `account.21bitcoin.app` の assetlinks.json（重要）
```json
[{
  "relation": [
    "delegate_permission/common.handle_all_urls",
    "delegate_permission/common.get_login_creds"
  ],
  "target": {
    "namespace": "android_app",
    "package_name": "fior.digital21app",
    "sha256_cert_fingerprints": [
      "6D:9C:D9:75:06:18:49:EA:3E:8F:85:7D:85:60:C0:CA:BD:6E:13:76:AF:B3:B8:C0:75:23:FE:09:66:5A:E0:F0"
    ]
  }
}]
```

- **`common.get_login_creds`**: このドメインの認証情報をアプリと共有 → **`account.21bitcoin.app` が認証基盤**
- **`common.handle_all_urls`**: すべての URL をアプリで処理
- ルート `21bitcoin.app/.well-known/assetlinks.json` は **404**（Webflow のため）

### ★ `forms.21bitcoin.app`（404 だが 186KB の HTML）
- Web フォーム基盤（おそらくサードパーティ）
- 186KB の 404 ページ → SPA か大規模フレームワーク

### 技術スタック推定
| 層 | 技術 |
|---|---|
| マーケサイト | **Webflow** + jQuery 3.5.1 + GSAP |
| アプリ（Web/SPA） | **`account.21bitcoin.app`** — フレームワーク未特定（body 空のシェル） |
| CDN/WAF | **Cloudflare** |
| モバイル | Android（Kotlin/Java?）/ iOS（Swift?） |
| 親会社 | FIOR Digital GmbH（オーストリア、MiCAR 認証） |

### 調査方針（更新）

| 優先 | 対象 | 理由 |
|---|---|---|
| **1** | **`account.21bitcoin.app`** | **アプリの中核**。認証基盤。SPA の JS から API を特定 |
| **2** | モバイルアプリ（APK） | 中核製品。静的解析で API エンドポイント抽出 |
| **3** | `forms.21bitcoin.app` | フォーム基盤。XSS/インジェクションの可能性 |
| **4** | マーケサイト | Webflow のため攻撃面は限定的 |
| 除外 | ヘッダ欠如・古い jQuery 等 | 明示的に報酬対象外 |

### 次のステップ
1. `account.21bitcoin.app` の JS バンドルを特定（`/` の HTML に script タグが無いため、
   別のエントリかリダイレクトを確認）
2. API エンドポイントの特定（SPA のバンドル or APK から）
3. 認証フロー（ログイン・2FA）の把握

---

## 追加検証：`account.21bitcoin.app` は空（2026-11-12 23:55）

ブラウザ相当の完全なヘッダで再取得:

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>21bitcoin</title>
<meta property="og:site_name" content="21bitcoin">
<meta property="og:title" content="21bitcoin">
<link rel="icon" href="/favicon.ico" sizes="any">
... (アイコンのみ)
</head>
<body><script type="module" src="https://static.cloudflareinsights.com/beacon.min.js/..." ...></script></body>
</html>
```

- **本文にアプリの JS バンドルが一切無い**
- Cloudflare Insights のビーコン（`spa: 2`）のみ
- ルート以外の全パスは 404（27150 バイトの 404 ページ）
- `server: cloudflare` / `cf-cache-status: DYNAMIC`

### 結論
**`account.21bitcoin.app` は未デプロイ、または機能していないエンドポイント。**
SPA としての実体を持たず、API エンドポイントを特定できない。

### その他のホスト
| ホスト | 実体 |
|---|---|
| `forms.21bitcoin.app` | **Typeform**（`<title>Question mark</title>`、第三者サービス） |
| `data.` `feedback.` `de.` `en.` | 接続不可 |
| `email.*` | メール基盤 |
| **`api.21bitcoin.app`** | **NXDOMAIN**（存在しない） |

### 到達できる攻撃面の総括
| 対象 | 到達 | 攻撃面 |
|---|---|---|
| **モバイルアプリ（中核）** | **取得不可**（Play/App Store のバイナリ、APKMirror にも無し） | — |
| `21bitcoin.app`（Webflow） | ✅ | 静的サイト、攻撃面は限定的（ヘッダ系は除外対象） |
| `account.21bitcoin.app` | ✅ | **空のシェル** |
| `forms.21bitcoin.app` | ✅ | **Typeform（第三者）** |
| API | ❌ | **未発見** |

**→ プログラムが「中核」とするモバイルアプリに到達できず、Web 側も空または第三者。**
   **現環境では In Scope の攻撃面に実質的に到達できない。**
