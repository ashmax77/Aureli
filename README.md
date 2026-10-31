# Aureli — Personal Wealth Management & Financial Intelligence

[![Render Deployment](https://img.shields.io/badge/Backend%20Status-Live%20on%20Render-46E3B7?style=flat&logo=render&logoColor=white)](https://aureli-9twx.onrender.com/api/health)
[![Backend](https://img.shields.io/badge/Backend-Spring%20Boot%204%20(Java%2021)-0B3B5A.svg?style=flat&logo=springboot)](https://spring.io/projects/spring-boot)
[![Frontend](https://img.shields.io/badge/Frontend-Flutter%203.x%20(Dart)-02569B.svg?style=flat&logo=flutter)](https://flutter.dev)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%20(Supabase)-3ECF8E.svg?style=flat&logo=supabase)](https://supabase.com)
[![Auth](https://img.shields.io/badge/Auth-Firebase%20Authentication-FFCA28.svg?style=flat&logo=firebase)](https://firebase.google.com)

**Aureli** is an intelligent, full-stack personal finance and wealth management platform designed to help users take disciplined control of their money. Rather than merely recording past expenses, Aureli introduces proactive financial intelligence: **automated & customizable savings reservations**, **spendable liquid allowance tracking**, **scheduled bill reminders with 1-tap payments**, and **dynamic category budget enforcement**, **debt & receivables tracking**, and **lifetime financial milestones**.

The system features a **Flutter 3 mobile application** offering both a dark glassmorphic aesthetic (default) and a crisp modern light theme, powered by a **Spring Boot 4 (Java 21) REST backend** hosted 24/7 on **Render**, backed by a **Supabase PostgreSQL** database, and integrated with **Firebase Cloud Messaging (FCM)** for automated notifications.

---

## 🌟 Key Features

### 🏦 Flexible Savings Vault & Income Allocation Control
* **User-Driven Savings Choice**: When recording any income, users can toggle whether they wish to allocate a portion toward savings or keep 100% of the income liquid and available for spending.
* **Customizable Allocation Rate**: When savings is enabled, fine-tune the reservation percentage (e.g. 10%, 20%, 30%) on the fly or retain your default preference.
* **Locked & Protected Wealth**: Reserved savings are mathematically segregated from discretionary funds—expense transactions cannot eat into this allocation.
* **Cumulative Savings Vault**: Prominently displayed on the Home dashboard to track your growing wealth over time.

### 🌓 Dual Themes: Dark Glassmorphic & Clean Light Mode
* **Dark Theme (Default)**: Deep midnight obsidian tones paired with frosted-glass surfaces, neon-emerald accents, and smooth gradient highlights.
* **Light Theme**: A crisp, high-contrast white aesthetic with subtle card elevations and clear readability for bright daylight environments.
* **Instant Switching**: Toggle seamlessly between dark and light modes at any time in Profile Settings with persistent local state.

### 🛡️ Spendable Liquid Allowance & Budget Enforcement
* **Net Spendable Allowance Calculation**: Instantly computes actual spendable money using the formula:
  $$\text{Spendable Allowance} = \max\Big(0, \text{Income} - \text{Monthly Reserved Savings} - \text{Scheduled Pending Bills}\Big)$$
* **Unallocated Allowance Tracking**: Visually warns if category budget limits exceed what remains of your liquid allowance.
* **Category Budget Limits**: Establish individual spending ceilings for each category with real-time percentage progress bars and breach alerts (`NORMAL`, `NEARING_90`, `EXCEEDED_100`).

### 🏷️ Dynamic Categories & Tailored Defaults
* **Custom Category Creation**: Add new user-defined expense or income categories directly from the Budgets tab.
* **Default Category Presets**:
  * **8 Expense Categories**: Groceries, Dining, Transport, Utilities, Entertainment, Housing, Education, and Medicine.
  * **4 Income Categories**: Salary, Freelance, Investment, Other.

### 🚀 Interactive Onboarding Setup
* Guides first-time users through configuring their monthly income, setting an initial savings preference, and strategically distributing remaining spendable funds across essential budget categories.

### ⏰ Scheduled Bills & Smart Reminder Engine
* **Recurring & One-Time Bills**: Manage commitments across `Weekly`, `Monthly`, and `Yearly` cycles with relative due badges (`Due Today`, `Due in 2 days`, `Overdue`).
* **1-Tap "Pay Now" Execution**: Instantly records the payment in the transaction ledger and automatically rolls recurring bills forward to their next due date.
* **Automated Cron Alerts**: Spring Boot background workers scan pending commitments daily (08:00) to dispatch Firebase Cloud Messaging (FCM) push notifications and persistent in-app notifications.

### 🤝 Debts & Receivables
* **Borrowed & Lent Tracking**: Record money you owe (`BORROWED`) or money owed to you (`LENT`), each with a counterparty, principal, optional interest rate, and due date.
* **Repayment Ledger**: Log partial or full repayments; remaining balance and status update automatically.
* **Lifecycle Status**: Debts move through `ACTIVE`, `SETTLED`, `OVERDUE`, and `CANCELLED` states.
* **Due Date Reminders**: Set how many days before the due date you want a reminder. A background scheduler also flags overdue debts and sends notifications.

### 🏆 Lifetime Financial Milestones
* **Lifetime Stats**: Cumulative financial statistics across your whole account history, optionally filtered by year.
* **Achievements**: Unlockable milestones that reward consistent money management, shown in a dedicated Lifetime Journey view.

### 📊 Real-Time Financial Dashboard & Analytics
* **At-a-Glance Intelligence**: Displays current month expenses, total income, net cash flow, and month-over-month trend pills.
* **Dashboard Summary**: A single aggregated endpoint feeds the dashboard, including cash, card, and bank transfer expense breakdowns.
* **Savings Goal**: Track progress toward a personal savings goal directly from the dashboard.
* **Interactive Charts**: Category spend breakdowns, multi-month spending trends, and a weekly expense trend chart powered by `fl_chart`.
* **Global Quick-Action FAB**: One-tap access to log expenses, record income, or schedule bills from any tab.

### 💳 Transaction Management
* Search transactions by description or category, and filter across custom date ranges with real-time balance calculations.
* **CSV Export**: Download filtered transactions as a CSV file. Exports are capped at **5,000 rows**; narrow the date range or filters if you exceed the limit.

### 📡 Network Resiliency & Offline Mode
* **Smart Offline Queue**: Allows users to save transactions securely offline when facing poor internet connectivity or server latency.
* **Optimistic UI Updates**: Offline transactions instantly appear on the dashboard with a pending status to prevent duplicate entries.
* **Background Auto-Sync**: Queued transactions are seamlessly and automatically pushed to the cloud once a stable internet connection is restored.
* **Idempotent Transaction Sync**: Each transaction carries a client-generated request ID that is reused across network retries and offline replay, so the backend returns the existing transaction instead of creating a duplicate.
* **Cached Snapshots**: Budget, debt, and profile data is cached locally with a save timestamp and schema version. Caches from an older schema are discarded, and the cache age is shown so users know how fresh the data is.
* **Safe Offline Sync Ordering**: The offline queue syncs under a concurrency lock, and auth and profile syncs use generation counters so a superseded response is ignored.

### 🔒 Enterprise-Grade Security
* **AES-256 Encrypted Storage**: All sensitive credentials and session tokens are encrypted using the hardware-backed Android Keystore via `flutter_secure_storage`.
* **Network Security Configuration**: Cleartext HTTP traffic is blocked at the OS level, and user-installed CA certificates are rejected to prevent Man-in-the-Middle (MITM) attacks.
* **Continuous Security Auditing**: The codebase undergoes regular Static (SAST) and Dynamic (DAST) application security testing to ensure compliance with modern secure coding standards.
* **Client-Side Debouncing**: Form submission guards prevent duplicate requests or burst spam.
* **Biometric App Lock**: Optional fingerprint or face unlock on app launch, powered by `local_auth`.
* **Per-User Rate Limiting**: The API allows 60 requests per minute per authenticated user (falling back to IP for unauthenticated requests) and returns `429 Too Many Requests` when exceeded.
* **Ownership Enforcement**: Devices, scheduled bills, transactions, debts, and categories are scoped to the authenticated user, so one account cannot read or modify another's records.
* **Zero Log Leakage**: Debug print statements and error traces are strictly restricted to `kDebugMode`.

---

## 🏗️ System Architecture

Aureli utilizes a decoupled, cloud-hosted client-server architecture:

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       Aureli Ecosystem                                           │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘

                                    ┌─────────────────────────────┐
                                    │     Firebase Auth & FCM     │
                                    │  • ID Token Issuance        │
                                    │  • Push Delivery Service    │
                                    └──────────────┬──────────────┘
                                                   │
                         Firebase ID Token         │  FCM Device Token & Push
                         Authentication            │  Notification Trigger
                                │                  │
                                ▼                  ▼
┌──────────────────────────────────────┐       HTTPS REST       ┌──────────────────────────────────┐
│             Flutter App              │ ─────────────────────> │      Spring Boot REST API        │
│          (Android / iOS)             │   (Bearer JWT Token)   │       (Java 21 on Render)        │
│                                      │                        │                                  │
│  • Dark & Light Dual Theming         │                        │  • Security Filter (Admin SDK)   │
│  • Provider State Architecture       │                        │  • Savings & Budget Calculator   │
│  • Live Cloud API (Render Hosted)    │                        │  • Scheduled Cron Jobs (Worker)  │
│  • AES-256 Secure Local Storage      │                        │  • JPA / Hibernate Repositories  │
└──────────────────────────────────────┘                        └─────────────────┬────────────────┘
                                                                                  │
                                                                                  │ JDBC Connection
                                                                                  │ (Transaction Pooler)
                                                                                  ▼
                                                                ┌──────────────────────────────────┐
                                                                │      Supabase PostgreSQL         │
                                                                │                                  │
                                                                │  • Users & Savings Rate Config   │
                                                                │  • Transactions & Categories     │
                                                                │  • Scheduled Bills & Reminders   │
                                                                │  • Category Budgets & Alerts     │
                                                                └──────────────────────────────────┘
```

---

## 💻 Tech Stack

| Domain | Technology | Description |
| :--- | :--- | :--- |
| **Mobile Client** | **Flutter 3.x / Dart 3.x** | Native Android application with cross-platform architecture. |
| **State Management** | **Provider** | Reactive, scalable state management across the app. |
| **Mobile UI** | **Material 3 + Glassmorphism** | Dual dark/light theme with frosted blur surfaces and responsive layout. |
| **Charts** | **fl_chart** | Smooth vector graphics for financial trends and category breakdowns. |
| **Local Security** | **FlutterSecureStorage** | AES-256 hardware-backed encryption via Android Keystore. |
| **Backend Framework** | **Spring Boot 4.x (Java 21)** | Enterprise-grade REST microservice hosted live 24/7 on Render. |
| **Database** | **PostgreSQL (Supabase)** | Cloud PostgreSQL database with high-performance connection pooling. |
| **Schema Migrations** | **Flyway** | Versioned SQL migrations (RLS policies, debt tables, indexes, lifetime stats, transaction idempotency). |
| **Rate Limiting** | **Bucket4j** | Per-user request throttling (60 requests/minute). |
| **Biometric Lock** | **local_auth** | Optional fingerprint / face unlock for the app. |
| **Authentication** | **Firebase Auth** | Industry-standard authentication and token lifecycle handling. |
| **Push Notifications** | **Firebase Cloud Messaging (FCM)** | Automated push alerts for due bills, debt reminders, and budget warnings. |
| **CI/CD & Security** | **GitHub Actions** | Build & test pipeline, beta release, GitGuardian secret scanning, and weekly DevSecOps scans. |

---


All requests require the authorization header:  
`Authorization: Bearer <FIREBASE_ID_TOKEN>`

Requests are rate limited to **60 per minute** per user. Exceeding the limit returns `429 Too Many Requests`.

### 👤 Users & Settings (`/api/v1`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/me` | Retrieve authenticated user profile and settings. |
| `PATCH` | `/api/v1/me/savings-rate` | Update monthly savings target percentage (between $5.0\%$ and $20.0\%$). |
| `PATCH` | `/api/v1/me/onboarding` | Mark onboarding wizard completion status. |
| `PATCH` | `/api/v1/me/fcm-token` | Register or update mobile device FCM push token. |

### 🏷️ Categories (`/api/v1/categories`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/categories` | List all default and custom user categories. |
| `POST` | `/api/v1/categories` | Create a new custom category (`name`, `type`, `color`, `icon`). |
| `GET` | `/api/v1/categories/{id}` | Retrieve details of a specific category. |
| `PUT` | `/api/v1/categories/{id}` | Update an existing category. |
| `DELETE`| `/api/v1/categories/{id}` | Delete a custom category. |

### 📊 Budgets & Financial Summary (`/api/v1/budgets`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/budgets/summary` | Fetch month financial breakdown: Spendable Allowance, Reserved Savings, Cumulative Savings Vault, Category Limits, and alert states. |
| `GET` | `/api/v1/budgets/dashboard-summary` | Aggregate for the Home dashboard: income, expenses, net cash flow, previous-month expenses, spendable allowance, category budgets, and cash / card / bank transfer expense split. |
| `POST` | `/api/v1/budgets` | Set or update a spending limit for a specific category. |

### 💳 Transactions (`/api/v1/transactions`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/transactions` | Query paginated transactions with optional filters (`startDate`, `endDate`, `categoryId`, `search`). |
| `POST` | `/api/v1/transactions` | Record a new income or expense transaction. Include a unique `clientRequestId`; reusing it for retries safely returns the original transaction. |
| `GET` | `/api/v1/transactions/export` | Download filtered transactions as `transactions.csv` (same filters as the list endpoint). Returns `413 Payload Too Large` above 5,000 rows. |
| `GET` | `/api/v1/transactions/{id}` | Get transaction details. |
| `PUT` | `/api/v1/transactions/{id}` | Update an existing transaction. |
| `DELETE`| `/api/v1/transactions/{id}` | Delete a transaction. |

For transaction creation, `clientRequestId` is scoped to the authenticated user and should remain unchanged when a request is retried or moved into the offline queue. The backend enforces this uniqueness at the database level.

### ⏰ Scheduled Bills (`/api/v1/scheduled-transactions`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/scheduled-transactions` | List all upcoming and paid scheduled commitments. |
| `POST` | `/api/v1/scheduled-transactions` | Schedule a new bill (`ONE_TIME`, `WEEKLY`, `MONTHLY`, `YEARLY`). |
| `PUT` | `/api/v1/scheduled-transactions/{id}` | Update scheduled bill details or due date. |
| `DELETE`| `/api/v1/scheduled-transactions/{id}` | Cancel/delete a scheduled bill. |
| `POST` | `/api/v1/scheduled-transactions/{id}/pay` | **1-Tap Pay Now**: Logs payment to expenses and advances recurring schedule. |

### 🤝 Debts & Receivables (`/api/v1/debts`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/debts/summary` | Total lent (receivables), total borrowed (liabilities), net debt position, active counts, and overdue count. |
| `GET` | `/api/v1/debts` | List debts, optionally filtered by `type` (`BORROWED`, `LENT`) and `status` (`ACTIVE`, `SETTLED`, `OVERDUE`, `CANCELLED`). |
| `POST` | `/api/v1/debts` | Create a new borrowed or lent debt record. |
| `GET` | `/api/v1/debts/{id}` | Get debt details and repayment history. |
| `PUT` | `/api/v1/debts/{id}` | Update a debt record. |
| `POST` | `/api/v1/debts/{id}/repayments` | Record a repayment against a debt. |
| `DELETE`| `/api/v1/debts/{id}` | Delete a debt record. |

### 🏆 Lifetime Milestones (`/api/v1/lifetime`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/lifetime/stats` | Cumulative lifetime financial statistics. Optional `year` query parameter narrows the result. |
| `GET` | `/api/v1/lifetime/achievements` | List achievements with their description, unlock status, and unlock date. |

### 📈 Charts & Trends (`/api/v1/charts`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/charts/monthly-trends` | Get historical spending trends for the last $N$ months. |
| `GET` | `/api/v1/charts/category-breakdown` | Get category spending distribution for charts. |

### 🔔 Notifications (`/api/v1/notifications`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/notifications` | Fetch notification inbox history. |
| `GET` | `/api/v1/notifications/unread-count`| Get unread notifications counter for badge display. |
| `POST` | `/api/v1/notifications/mark-read` | Mark all notifications as read. |

### 🩺 System (`/api/v1`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/health` | Healthcheck endpoint returning server uptime status. Public, not rate limited. |

---

## 📲 How to Install the App on an Android Phone

> **Note**: The backend is already hosted and running live on Render. You do **not** need to set up, configure, or host any backend servers or databases. The app connects directly to the cloud backend out of the box.

### Step 1: Download from Google Drive
The latest `app-release.apk` is hosted in our shared Google Drive folder.
1. Open the Google Drive folder link on your Android phone.
2. Tap on the `app-release.apk` file to download it to your device.

---

### Step 2: Install the App
1. Once downloaded, tap on the `app-release.apk` file from your notification panel or the **Downloads** folder.
2. If Android displays **"For your security, your phone is not allowed to install unknown apps from this source"**:
   - Tap **Settings** in the prompt.
   - Toggle **Allow from this source** to **ON**.
   - Return to the installer and tap **Install**.
3. Tap **Open** to launch Aureli!

---

### Step 3: Mark Your Transactions Effectively
1. Open **Aureli** and tap **Sign Up** to create an account (or **Log In** if you already have one).
2. Complete the quick initial onboarding setup to configure your monthly income, savings preference, and category budgets.
3. Start marking your transactions and managing your wealth effectively!
