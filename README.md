# Aureli — Personal Wealth Management & Financial Intelligence

[![Render Deployment](https://img.shields.io/badge/Backend%20Status-Live%20on%20Render-46E3B7?style=flat&logo=render&logoColor=white)](https://aureli-9twx.onrender.com/api/v1/health)
[![Backend](https://img.shields.io/badge/Backend-Spring%20Boot%203%20(Java%2021)-0B3B5A.svg?style=flat&logo=springboot)](https://spring.io/projects/spring-boot)
[![Frontend](https://img.shields.io/badge/Frontend-Flutter%203.x%20(Dart)-02569B.svg?style=flat&logo=flutter)](https://flutter.dev)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%20(Supabase)-3ECF8E.svg?style=flat&logo=supabase)](https://supabase.com)
[![Auth](https://img.shields.io/badge/Auth-Firebase%20Authentication-FFCA28.svg?style=flat&logo=firebase)](https://firebase.google.com)

**Aureli** is an intelligent, full-stack personal finance and wealth management platform designed to help users take disciplined control of their money. Rather than merely recording past expenses, Aureli introduces proactive financial intelligence: **automated monthly savings reservation**, **spendable liquid allowance tracking**, **scheduled bill reminders with 1-tap payments**, and **dynamic category budget enforcement**.

The system features a **Flutter 3 mobile application** wrapped in a dark glassmorphic UI, powered by a **Spring Boot 3 (Java 21) REST backend** deployed 24/7 on **Render**, backed by a **Supabase PostgreSQL** database, and integrated with **Firebase Cloud Messaging (FCM)** for automated notifications.

---

## 🌟 Key Features

### 🏦 Automated Savings Vault & Reserve Allocation *(Latest)*
* **Guaranteed Savings Floor**: Set aside an automated percentage of monthly income (mandatory minimum 5%, recommended 20%–25%) reserved strictly for wealth building.
* **Locked & Protected**: Reserved savings are mathematically segregated from discretionary funds—expense transactions cannot eat into this allocation.
* **Cumulative Savings Vault**: Visualized prominently on the Home dashboard, tracking cumulative saved wealth growing month-over-month.
* **Instant Target Adjustment**: Fine-tune your monthly savings target anytime directly from a glassmorphic dashboard modal.

### 🛡️ Spendable Liquid Allowance & Budget Enforcement *(Latest)*
* **Net Spendable Allowance Calculation**: Instantly computes actual spendable money using the formula:
  $$\text{Spendable Allowance} = \max\Big(0, \text{Income} - \text{Monthly Reserved Savings} - \text{Scheduled Pending Bills}\Big)$$
* **Unallocated Allowance Tracking**: Visually warns if category budget limits exceed what remains of your liquid allowance.
* **Category Budget Limits**: Establish individual spending ceilings for each category with real-time percentage progress bars and breach alerts (`NORMAL`, `NEARING_90`, `EXCEEDED_100`).

### 🏷️ Dynamic Categories & Tailored Defaults *(Latest)*
* **Custom Category Creation**: Add new user-defined expense or income categories on the fly directly from the Budgets tab.
* **Default Category Presets**:
  * **8 Expense Categories**: Groceries, Dining, Transport, Utilities, Entertainment, Housing, plus newly added **Education** and **Medicine**.
  * **4 Income Categories**: Salary, Freelance, Investment, Other.

### 🚀 Interactive Onboarding Setup *(Latest)*
* Guides first-time users through configuring their monthly income, locking in an initial savings rate (5%–50%), and strategically distributing remaining spendable funds across essential budget categories.

### ⏰ Scheduled Bills & Smart Reminder Engine
* **Recurring & One-Time Bills**: Manage scheduled expenses across `Weekly`, `Monthly`, and `Yearly` cycles with relative due badges (`Due Today`, `Due in 2 days`, `Overdue`).
* **1-Tap "Pay Now" Execution**: Instantly records the actual payment in the transaction ledger and automatically rolls recurring bills forward to their next due date.
* **Automated Cron Alerts**: Spring Boot background workers scan pending commitments daily to dispatch Firebase Cloud Messaging (FCM) push notifications and persistent in-app notifications.

### 📊 Real-Time Financial Dashboard & Analytics
* **At-a-Glance Intelligence**: Displays current month expenses, total income, net cash flow, and month-over-month trend pills (e.g. `📈 8.4% more than previous month`).
* **Interactive Charts**: Category spend breakdowns and 6-month spending trends powered by `fl_chart`.
* **Global Quick-Action FAB**: One-tap access to log expenses, record income, or schedule bills from any tab.

### 💳 Transaction Management & CSV Export
* Search transactions by description or category, filter across custom date ranges, and export complete account statements directly to a CSV stream.

### 🔮 Pinned Future Roadmap
* **Direct Bank Integration**: Integration with open-banking protocols to automatically ingest bank transactions and sync balances.
* **Custom Financial Month Boundaries**: Align monthly budget cycles with individual salary paydays rather than standard calendar month dates.
* **Pre-marked Future Expenses**: Earmark dedicated funds for upcoming milestone events (e.g. celebrations, travel) without skewing regular category budgets.

---

## 🏗️ System Architecture

Aureli utilizes a decoupled, cloud-hosted client-server architecture designed for reliability, fast response times, and cross-platform flexibility:

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
│  • Material 3 Dark Glassmorphism     │                        │  • Security Filter (Admin SDK)   │
│  • Provider State Architecture       │                        │  • Savings & Budget Calculator   │
│  • Live API Service (Render Hosted)  │                        │  • Scheduled Cron Jobs (Worker)  │
│  • Cached User & Settings            │                        │  • JPA / Hibernate Repositories  │
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

### Architectural Highlights
1. **Stateless Security**: The mobile client handles authentication directly via Firebase SDK. The Spring Boot backend validates incoming Firebase ID tokens using the Firebase Admin SDK and maps claims to the PostgreSQL `users` entity.
2. **Automated Cron Jobs**: Spring Boot's `@Scheduled` workers periodically evaluate upcoming due dates to dispatch background FCM notifications.
3. **Optimized Latency**: Mobile dashboards execute parallelized network calls (`Future.wait`) to simultaneously retrieve user profiles, transactions, scheduled bills, and budget metrics.

---

## 💻 Tech Stack

| Domain | Technology | Description |
| :--- | :--- | :--- |
| **Mobile Client** | **Flutter 3.x / Dart 3.x** | Cross-platform framework supporting native Android and iOS. |
| **State Management** | **Provider** | Predictable, scalable reactive state management (`MultiProvider`). |
| **Mobile UI** | **Material 3 + Glassmorphism** | Custom dark theme with frosted blur surfaces (`GlassCard`) and micro-animations. |
| **Charts** | **fl_chart** | Smooth vector graphics for trends and category breakdowns. |
| **Backend Framework** | **Spring Boot 3.x (Java 21)** | Enterprise-grade REST microservice utilizing Spring Data JPA and validation. |
| **Backend Hosting** | **Render (Cloud Platform)** | 24/7 managed production container environment. |
| **Database** | **PostgreSQL (Supabase)** | Managed PostgreSQL with connection pooling on AWS ap-south-1. |
| **Authentication** | **Firebase Auth** | Secure email/password and token lifecycle handling. |
| **Push Notifications** | **Firebase Cloud Messaging (FCM)** | Automated push alerts for due bills and budget warnings. |
| **Build Tools** | **Maven & Flutter CLI** | Dependency management, testing, and continuous deployment. |

---

## 🔌 Complete REST API Reference

All requests must include the header:  
`Authorization: Bearer <FIREBASE_ID_TOKEN>`

### 👤 Users & Settings (`/api/v1`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/me` | Retrieve authenticated user profile and settings. |
| `PATCH` | `/api/v1/me/savings-rate` | Update monthly savings target percentage ($\ge 5.0\%$). |
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
| `POST` | `/api/v1/budgets` | Set or update a spending limit for a specific category. |

### 💳 Transactions (`/api/v1/transactions`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/transactions` | Query paginated transactions with optional filters (`startDate`, `endDate`, `categoryId`, `search`). |
| `POST` | `/api/v1/transactions` | Record a new income or expense transaction. |
| `GET` | `/api/v1/transactions/{id}` | Get transaction details. |
| `PUT` | `/api/v1/transactions/{id}` | Update an existing transaction. |
| `DELETE`| `/api/v1/transactions/{id}` | Delete a transaction. |
| `GET` | `/api/v1/transactions/export` | Download a complete CSV stream of transactions. |

### ⏰ Scheduled Bills (`/api/v1/scheduled-transactions`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/scheduled-transactions` | List all upcoming and paid scheduled commitments. |
| `POST` | `/api/v1/scheduled-transactions` | Schedule a new bill (`ONE_TIME`, `WEEKLY`, `MONTHLY`, `YEARLY`). |
| `PUT` | `/api/v1/scheduled-transactions/{id}` | Update scheduled bill details or due date. |
| `DELETE`| `/api/v1/scheduled-transactions/{id}` | Cancel/delete a scheduled bill. |
| `POST` | `/api/v1/scheduled-transactions/{id}/pay` | **1-Tap Pay Now**: Logs payment to expenses and advances recurring schedule. |

### 📈 Charts & Trends (`/api/v1/charts`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/charts/monthly-trends` | Get historical spending trends for the last $N$ months. |
| `GET` | `/api/v1/charts/category-breakdown` | Get category spending distribution for pie charts. |

### 🔔 Notifications (`/api/v1/notifications`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/notifications` | Fetch notification inbox history. |
| `GET` | `/api/v1/notifications/unread-count`| Get unread notifications counter for badge display. |
| `POST` | `/api/v1/notifications/mark-read` | Mark all notifications as read. |

### 🩺 System (`/api/v1`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/health` | Healthcheck endpoint returning server uptime status. |

---

## 📱 How to Download & Run the App

The Aureli backend is **already hosted and live 24/7 on Render** at:  
👉 **`https://aureli-9twx.onrender.com/api/v1`**

Because the mobile client is already configured to communicate with this live cloud backend, **you do not need to set up or run the Java backend locally to use or test the app**.

### 📦 Option 1: Build the Release APK (Recommended for Android)

You can compile and package the standalone Android APK on your machine in just a few minutes:

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ashmax77/Money-Manager.git
   cd Money-Manager/mobile
   ```

2. **Fetch Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Build the production release APK**:
   ```bash
   flutter build apk --release
   ```

4. **Locate and Install the APK**:
   Once the build completes, the standalone installable APK is located at:
   ```
   mobile/build/app/outputs/flutter-apk/app-release.apk
   ```
   * Transfer this `.apk` file to your Android phone (via USB, Google Drive, or email) and tap it to install (**Allow installation from unknown sources** if prompted).

> [!NOTE]
> **Pre-built GitHub Release**: Direct 1-click download links for `app-release.apk` will soon be published under this repository's **[Releases](https://github.com/ashmax77/Money-Manager/releases)** section. In the meantime, running `flutter build apk --release` generates the identical production binary.

---

### 💻 Option 2: Run in Debug / Development Mode

If you have an Android device connected via USB or an Android Emulator / iOS Simulator running:

```bash
cd mobile
flutter pub get
flutter run
```

---

### ⚙️ Option 3: Running the Backend Locally (Optional for Developers)

If you wish to modify backend business logic or run your own local Spring Boot instance:

#### Prerequisites
* **Java 21 JDK**
* **Maven 3.8+**
* Local or cloud **PostgreSQL** instance

#### Steps
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Configure environment variables (or create an `application-local.properties`):
   ```bash
   export SPRING_DATASOURCE_URL="jdbc:postgresql://localhost:5432/money_manager"
   export SPRING_DATASOURCE_USERNAME="your_user"
   export SPRING_DATASOURCE_PASSWORD="your_password"
   export FIREBASE_CREDENTIALS_PATH="src/main/resources/serviceAccountKey.json"
   ```

3. Run the Spring Boot application:
   ```bash
   ./mvnw spring-boot:run
   ```

4. Verify backend health:
   ```bash
   curl http://localhost:8080/api/v1/health
   # Returns: {"status":"UP"}
   ```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
